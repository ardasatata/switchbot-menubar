//
//  AppStore.swift
//  switch-bot-menu-bar
//
//  The single source of truth for the app. Owned by the App struct
//  (@State, injected via .environment) rather than by any view, because
//  MenuBarExtra(.window) tears down and recreates its content view on every
//  open/close — a store owned by the view would silently reset state each
//  time the menu closes.
//

import Foundation
import Observation

@Observable
@MainActor
final class AppStore {
    enum AuthState: Equatable {
        case loading
        case needsOnboarding
        case demo
        case ready
    }

    private(set) var authState: AuthState = .loading
    private(set) var devices: [Device] = []
    private(set) var statuses: [String: DeviceStatus] = [:]
    private(set) var scenes: [SceneItem] = []
    private(set) var lastError: SwitchBotError?
    private(set) var isRefreshing = false
    private(set) var isNearRateLimit = false
    private(set) var isDemoMode = false

    var pinnedDeviceIds: Set<String> = []
    var deviceOrder: [String] = []
    var customNames: [String: String] = [:]
    var backgroundRefreshMinutes: Int? // nil = off

    /// Optimistic overlays, keyed by deviceId, cleared on confirmation or error.
    private var optimistic: [String: (status: DeviceStatus, expiresAt: Date)] = [:]

    private let credentialStore: CredentialStore
    private let diskCache: DiskCache
    private let rateLimiter = RateLimiter()
    private var client: SwitchBotClient?
    private var statusFetchTimestamps: [String: Date] = [:]
    private var refreshLoopTask: Task<Void, Never>?

    private let statusTTL: TimeInterval = 60
    private let openRefreshInterval: Duration = .seconds(30)
    private let optimisticDuration: TimeInterval = 8
    private let confirmationDelay: Duration = .seconds(3)

    /// Factory for the real (non-demo) HTTPClient — injectable so tests can
    /// substitute a stub instead of hitting the network via URLSession.
    private let httpClientFactory: @Sendable () -> HTTPClient

    init(
        credentialStore: CredentialStore = KeychainCredentialStore(),
        diskCache: DiskCache = DiskCache(),
        httpClientFactory: @escaping @Sendable () -> HTTPClient = { URLSessionHTTPClient() }
    ) {
        self.credentialStore = credentialStore
        self.diskCache = diskCache
        self.httpClientFactory = httpClientFactory
    }

    // MARK: - Startup

    func start() async {
        let cached = await diskCache.load()
        devices = cached.devices
        statuses = cached.statuses
        scenes = cached.scenes
        pinnedDeviceIds = cached.pinnedDeviceIds
        deviceOrder = cached.deviceOrder
        customNames = cached.customNames

        if let credentials = credentialStore.load() {
            configureClient(with: credentials)
            authState = .ready
            await refreshDevicesIfStale()
        } else {
            authState = .needsOnboarding
        }
    }

    private func configureClient(with credentials: SwitchBotCredentials) {
        client = SwitchBotClient(httpClient: httpClientFactory(), credentials: credentials)
        isDemoMode = false
    }

    // MARK: - Onboarding / credentials

    /// Validates by calling GET /v1.1/devices before persisting anything.
    func saveCredentials(token: String, secret: String) async throws {
        let credentials = SwitchBotCredentials(token: token, secret: secret)
        let candidate = SwitchBotClient(httpClient: httpClientFactory(), credentials: credentials)
        let fetched = try await candidate.devices()

        try credentialStore.save(credentials)
        client = candidate
        isDemoMode = false
        devices = fetched
        authState = .ready
        lastError = nil
        await persistCache()
        await refreshVisibleStatuses(deviceIds: fetched.map(\.id))
    }

    func enterDemoMode() {
        client = SwitchBotClient(httpClient: DemoHTTPClient(), credentials: SwitchBotCredentials(token: "demo", secret: "demo"))
        isDemoMode = true
        authState = .demo
        Task { await refreshDevicesIfStale(force: true) }
    }

    func exitDemoMode() {
        client = nil
        isDemoMode = false
        devices = []
        statuses = [:]
        scenes = []
        authState = credentialStore.load() != nil ? .ready : .needsOnboarding
        if authState == .ready, let credentials = credentialStore.load() {
            configureClient(with: credentials)
            Task { await refreshDevicesIfStale(force: true) }
        }
    }

    func clearCredentials() throws {
        try credentialStore.clear()
        client = nil
        isDemoMode = false
        devices = []
        statuses = [:]
        scenes = []
        authState = .needsOnboarding
    }

    // MARK: - Refresh policy
    //
    // SwitchBot has no bulk-status endpoint: GET /status is one call per
    // device against a 10,000/day budget. Naive 30s polling of 8 devices
    // would be 23,040 calls/day. So: device/scene lists are cached 24h,
    // status is fetched lazily per visible device gated by a 60s TTL, and
    // there's a single refresh loop only while the menu is open.

    func onMenuOpened() {
        Task { await refreshOnOpen() }
        refreshLoopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: self.openRefreshInterval)
                guard !Task.isCancelled else { return }
                await self.refreshVisibleStatuses(deviceIds: self.visibleDeviceIds())
            }
        }
    }

    func onMenuClosed() {
        refreshLoopTask?.cancel()
        refreshLoopTask = nil
    }

    /// The lazy, TTL-gated refresh that runs on menu open — exposed
    /// directly (rather than only inside the fire-and-forget Task in
    /// onMenuOpened) so tests can await it deterministically.
    func refreshOnOpen() async {
        await refreshDevicesIfStale()
        await refreshVisibleStatuses(deviceIds: visibleDeviceIds())
    }

    func manualRefresh() async {
        await refreshDevicesIfStale(force: true)
        await refreshVisibleStatuses(deviceIds: visibleDeviceIds(), force: true)
    }

    private func visibleDeviceIds() -> [String] {
        // Pinned devices are always visible; if none are pinned, treat the
        // first dozen (all, typically) as visible to keep things simple for
        // small accounts while still bounding cost for large ones.
        if !pinnedDeviceIds.isEmpty { return Array(pinnedDeviceIds) }
        return devices.filter { DeviceCatalog.profile(for: $0.deviceType, kind: $0.kind)?.hasStatusEndpoint ?? true }
            .prefix(12).map(\.id)
    }

    private func refreshDevicesIfStale(force: Bool = false) async {
        guard let client else { return }
        let cached = await diskCache.load()
        let isStale = force || cached.devicesFetchedAt.map { Date().timeIntervalSince($0) > 86_400 } ?? true
        guard isStale || devices.isEmpty else { return }

        do {
            try await rateLimiter.acquire()
            defer { Task { await rateLimiter.release() } }
            let fetched = try await client.devices()
            devices = fetched
            lastError = nil
            let sceneList = (try? await client.scenes()) ?? scenes
            scenes = sceneList
            await persistCache()
        } catch let error as RateLimiter.LimiterError {
            _ = error
            lastError = .rateLimitExhausted
        } catch let error as SwitchBotError {
            lastError = error
        } catch {
            lastError = .transport(error.localizedDescription)
        }
    }

    private func refreshVisibleStatuses(deviceIds: [String], force: Bool = false) async {
        guard let client else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        for deviceId in deviceIds {
            guard let device = devices.first(where: { $0.id == deviceId }) else { continue }
            guard DeviceCatalog.profile(for: device.deviceType, kind: device.kind)?.hasStatusEndpoint ?? true else { continue }

            let lastFetched = statusFetchTimestamps[deviceId]
            if !force, let lastFetched, Date().timeIntervalSince(lastFetched) < statusTTL { continue }

            do {
                try await rateLimiter.acquire()
                defer { Task { await rateLimiter.release() } }
                let status = try await client.status(deviceId: deviceId)
                statuses[deviceId] = status
                statusFetchTimestamps[deviceId] = Date()
                isNearRateLimit = await rateLimiter.isNearLimit
            } catch let error as RateLimiter.LimiterError {
                _ = error
                lastError = .rateLimitExhausted
                break
            } catch let error as SwitchBotError {
                // Don't let one offline device's error clobber a
                // successful refresh of the others; surface it, keep going.
                lastError = error
            } catch {
                lastError = .transport(error.localizedDescription)
            }
        }
        await persistCache()
    }

    // MARK: - Commands

    /// Optimistically applies `intent`'s expected effect, sends the command,
    /// then schedules a single confirmation fetch. Reverts immediately on error.
    func send(_ intent: ControlIntent, to device: Device) async {
        guard let client else { return }
        let previous = statuses[device.id]
        applyOptimistic(intent, to: device)

        let command = DeviceCommand.make(intent: intent, for: device)
        do {
            try await rateLimiter.acquire()
            defer { Task { await rateLimiter.release() } }
            try await client.sendCommand(command, to: device.id)
            lastError = nil
            try? await Task.sleep(for: confirmationDelay)
            if let refreshed = try? await client.status(deviceId: device.id) {
                statuses[device.id] = refreshed
                statusFetchTimestamps[device.id] = Date()
            }
            optimistic[device.id] = nil
            await persistCache()
        } catch let error as SwitchBotError {
            lastError = error
            statuses[device.id] = previous
            optimistic[device.id] = nil
        } catch {
            lastError = .transport(error.localizedDescription)
            statuses[device.id] = previous
            optimistic[device.id] = nil
        }
    }

    func executeScene(_ scene: SceneItem) async {
        guard let client else { return }
        do {
            try await rateLimiter.acquire()
            defer { Task { await rateLimiter.release() } }
            try await client.executeScene(scene.id)
            lastError = nil
        } catch let error as SwitchBotError {
            lastError = error
        } catch {
            lastError = .transport(error.localizedDescription)
        }
    }

    /// Effective status for a device, preferring an unexpired optimistic
    /// overlay over the last confirmed value from the server.
    func effectiveStatus(for deviceId: String) -> DeviceStatus? {
        if let overlay = optimistic[deviceId], overlay.expiresAt > Date() {
            return overlay.status
        }
        return statuses[deviceId]
    }

    private func applyOptimistic(_ intent: ControlIntent, to device: Device) {
        var raw = statuses[device.id]?.raw ?? [:]
        switch intent {
        case .turnOn: raw[StatusKey.power.rawValue] = .string("on")
        case .turnOff: raw[StatusKey.power.rawValue] = .string("off")
        case .toggle:
            let isOn = raw.string(StatusKey.power.rawValue) == "on"
            raw[StatusKey.power.rawValue] = .string(isOn ? "off" : "on")
        case .setBrightness(let value): raw[StatusKey.brightness.rawValue] = .number(Double(value))
        case .setColorRGB(let r, let g, let b): raw[StatusKey.color.rawValue] = .string("\(r):\(g):\(b)")
        case .setColorTemperature(let kelvin): raw[StatusKey.colorTemperature.rawValue] = .number(Double(kelvin))
        case .setPosition(let value): raw[StatusKey.slidePosition.rawValue] = .number(Double(value))
        case .lock: raw[StatusKey.lockState.rawValue] = .string("locked")
        case .unlock: raw[StatusKey.lockState.rawValue] = .string("unlocked")
        case .vacuumStart: raw[StatusKey.workingStatus.rawValue] = .string("cleaning")
        case .vacuumStop: raw[StatusKey.workingStatus.rawValue] = .string("standby")
        case .vacuumDock: raw[StatusKey.workingStatus.rawValue] = .string("docking")
        case .press, .setFanSpeed, .setMode, .irButton:
            break // no meaningful optimistic state to show
        }
        let overlay = DeviceStatus(deviceId: device.id, deviceType: device.deviceType, hubDeviceId: device.hubDeviceId, raw: raw, fetchedAt: Date())
        optimistic[device.id] = (overlay, Date().addingTimeInterval(optimisticDuration))
    }

    // MARK: - Capabilities

    func effectiveCapabilities(for device: Device) -> [Capability] {
        let profile = DeviceCatalog.profile(for: device.deviceType, kind: device.kind)
        var capabilities = Set(profile?.capabilities ?? [])
        if let status = effectiveStatus(for: device.id) {
            capabilities.formUnion(inferredCapabilities(from: status))
        }
        return capabilities.sorted { $0.sortRank < $1.sortRank }
    }

    /// The escape hatch that makes "every device the API exposes" hold even
    /// for types absent from DeviceCatalog: read the raw status bag and
    /// infer controls from whichever fields are actually present.
    private func inferredCapabilities(from status: DeviceStatus) -> Set<Capability> {
        var result: Set<Capability> = []
        if status.power != nil { result.insert(.power) }
        if status.brightness != nil { result.insert(.brightness(1...100)) }
        if status.colorTemperatureKelvin != nil { result.insert(.colorTemperature(2700...6500)) }
        if status.colorRGB != nil { result.insert(.colorRGB) }
        if status.slidePosition != nil { result.insert(.position(.curtain)) }
        if status.lockState != nil { result.insert(.lock) }
        if status.workingStatus != nil { result.insert(.vacuum) }
        for spec in ReadingSpec.all where spec.format(status) != nil {
            result.insert(.reading(spec.key))
        }
        return result
    }

    func category(for device: Device) -> DeviceCategory {
        DeviceCatalog.profile(for: device.deviceType, kind: device.kind)?.category ?? .other
    }

    func symbolName(for device: Device) -> String {
        DeviceCatalog.profile(for: device.deviceType, kind: device.kind)?.symbolName
            ?? (device.kind == .infrared ? "sparkles.tv" : "questionmark.circle")
    }

    func displayName(for device: Device) -> String {
        customNames[device.id] ?? device.name
    }

    // MARK: - Persistence

    private func persistCache() async {
        var state = await diskCache.load()
        state.devices = devices
        state.devicesFetchedAt = devices.isEmpty ? state.devicesFetchedAt : Date()
        state.scenes = scenes
        state.statuses = statuses
        state.pinnedDeviceIds = pinnedDeviceIds
        state.deviceOrder = deviceOrder
        state.customNames = customNames
        await diskCache.save(state)
    }
}
