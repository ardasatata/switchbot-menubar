//
//  DiskCache.swift
//  switch-bot-menu-bar
//
//  Atomic on-disk cache of devices, scenes, last-known statuses, and user
//  prefs (pinned/order/custom names) — never credentials, those live only
//  in the Keychain. Loaded at launch so the menu renders instantly with
//  last-known state before any network call completes.
//

import Foundation

struct CachedState: Codable, Sendable {
    var devices: [Device] = []
    var devicesFetchedAt: Date?
    var scenes: [SceneItem] = []
    var scenesFetchedAt: Date?
    var statuses: [String: DeviceStatus] = [:]
    var pinnedDeviceIds: Set<String> = []
    var deviceOrder: [String] = []
    var customNames: [String: String] = [:]
}

actor DiskCache {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = base.appendingPathComponent("switchbot-menubar", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("cache.json")
        }
    }

    func load() -> CachedState {
        guard let data = try? Data(contentsOf: fileURL) else { return CachedState() }
        return (try? JSONDecoder().decode(CachedState.self, from: data)) ?? CachedState()
    }

    func save(_ state: CachedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        let tempURL = fileURL.appendingPathExtension("tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
}
