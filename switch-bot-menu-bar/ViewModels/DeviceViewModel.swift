//
//  DeviceViewModel.swift
//  switch-bot-menu-bar
//
//  A thin per-device projection over AppStore. All actual state
//  (statuses, optimistic overlay, persistence) lives in AppStore; this just
//  bundles a Device with the store so views don't repeat
//  `store.effectiveStatus(for: device.id)` everywhere.
//

import Foundation

@MainActor
struct DeviceViewModel: Identifiable {
    let device: Device
    let store: AppStore

    nonisolated var id: String { device.id }

    var displayName: String { store.displayName(for: device) }
    var symbolName: String { store.symbolName(for: device) }
    var category: DeviceCategory { store.category(for: device) }
    var capabilities: [Capability] { store.effectiveCapabilities(for: device) }
    var status: DeviceStatus? { store.effectiveStatus(for: device.id) }
    var isPinned: Bool { store.pinnedDeviceIds.contains(device.id) }
    var isOn: Bool { status?.power == .on }

    func send(_ intent: ControlIntent) {
        Task { await store.send(intent, to: device) }
    }

    func togglePin() {
        if isPinned {
            store.pinnedDeviceIds.remove(device.id)
        } else {
            store.pinnedDeviceIds.insert(device.id)
        }
    }

    func reading(_ key: StatusKey) -> String? {
        guard let status, let spec = ReadingSpec.spec(for: key) else { return nil }
        return spec.format(status)
    }
}
