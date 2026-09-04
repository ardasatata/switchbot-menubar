//
//  DeviceCatalog.swift
//  switch-bot-menu-bar
//
//  Maps a SwitchBot `deviceType`/`remoteType` string to a DeviceProfile.
//  Matching is normalize -> exact -> longest-prefix, so regional suffixes
//  like "(US)"/"(JP)" and future SKU variants ("... V2", "... Pro") still
//  resolve to the right profile without an explicit table entry.
//
//  The catalog is a *polish* layer (icon, category, precise ranges) — not a
//  correctness requirement. AppStore.effectiveCapabilities(for:) unions
//  whatever this returns with capabilities inferred directly from the raw
//  status payload, so an unrecognized device type still gets working
//  controls. See DeviceStatus+Readings.swift / Capability.swift.
//

import Foundation

struct DeviceProfile: Sendable {
    let symbolName: String
    let category: DeviceCategory
    let capabilities: [Capability]
    let hasStatusEndpoint: Bool

    init(symbolName: String, category: DeviceCategory, capabilities: [Capability], hasStatusEndpoint: Bool = true) {
        self.symbolName = symbolName
        self.category = category
        self.capabilities = capabilities
        self.hasStatusEndpoint = hasStatusEndpoint
    }
}

enum DeviceCatalog {
    /// Normalizes a deviceType string for matching: lowercase, drop a
    /// trailing parenthesized region code, collapse whitespace.
    static func normalize(_ deviceType: String) -> String {
        var value = deviceType.lowercased()
        if let range = value.range(of: #"\s*\([^)]*\)\s*$"#, options: .regularExpression) {
            value.removeSubrange(range)
        }
        return value.trimmingCharacters(in: .whitespaces)
    }

    /// Exact-match table, keyed by normalized deviceType.
    private static let table: [String: DeviceProfile] = {
        var entries: [String: DeviceProfile] = [:]

        func add(_ types: [String], _ profile: DeviceProfile) {
            for type in types { entries[normalize(type)] = profile }
        }

        // Bot
        add(["Bot"], DeviceProfile(
            symbolName: "hand.tap", category: .other,
            capabilities: [.power, .press, .reading(.battery)]
        ))

        // Plugs & relays
        add(["Plug", "Plug Mini", "Relay Switch 1", "Relay Switch 1PM", "Relay Switch 2PM"],
            DeviceProfile(symbolName: "poweroutlet.type.b", category: .plugs, capabilities: [.power]))

        // Lighting
        add(["Color Bulb", "Strip Light", "Strip Light 3", "RGBICWW Strip Light"],
            DeviceProfile(symbolName: "lightbulb", category: .lighting,
                          capabilities: [.power, .brightness(1...100), .colorTemperature(2700...6500), .colorRGB]))
        add(["Ceiling Light", "Ceiling Light Pro", "RGBICWW Ceiling Light"],
            DeviceProfile(symbolName: "light.ceiling", category: .lighting,
                          capabilities: [.power, .brightness(1...100), .colorTemperature(2700...6500)]))

        // Climate
        add(["Circulator Fan", "Battery Circulator Fan", "Standing Circulator Fan"],
            DeviceProfile(symbolName: "fan", category: .climate, capabilities: [.power, .fanSpeed(levels: 100)]))
        add(["Humidifier", "Evaporative Humidifier"],
            DeviceProfile(symbolName: "humidity", category: .climate,
                          capabilities: [.power, .reading(.humidity), .reading(.temperature)]))
        add(["Air Purifier"],
            DeviceProfile(symbolName: "wind", category: .climate, capabilities: [.power, .reading(.pm25Value)]))
        add(["Meter", "Meter Plus", "Meter Pro", "Outdoor Meter", "WoIOSensor"],
            DeviceProfile(symbolName: "thermometer", category: .sensors,
                          capabilities: [.reading(.temperature), .reading(.humidity), .reading(.battery)],
                          hasStatusEndpoint: true))

        // Coverings
        add(["Curtain", "Curtain 3"],
            DeviceProfile(symbolName: "blinds.horizontal.closed", category: .coverings,
                          capabilities: [.position(.curtain), .reading(.battery)]))
        add(["Blind Tilt"],
            DeviceProfile(symbolName: "blinds.horizontal.closed", category: .coverings,
                          capabilities: [.position(.blindTilt), .reading(.battery)]))
        add(["Roller Shade"],
            DeviceProfile(symbolName: "blinds.vertical.closed", category: .coverings,
                          capabilities: [.position(.rollerShade), .reading(.battery)]))

        // Security
        add(["Smart Lock", "Lock", "Lock Pro", "Lock Ultra"],
            DeviceProfile(symbolName: "lock", category: .security, capabilities: [.lock, .reading(.battery)]))

        // Cleaning
        add(["Robot Vacuum Cleaner S1", "Robot Vacuum Cleaner S1 Plus", "Robot Vacuum Cleaner K10+",
             "Robot Vacuum Cleaner K10+ Pro", "Robot Vacuum Cleaner S10", "Robot Vacuum Cleaner S20",
             "Robot Vacuum Cleaner K11+", "Robot Vacuum Cleaner K20+ Pro"],
            DeviceProfile(symbolName: "roomba", category: .cleaning,
                          capabilities: [.vacuum, .reading(.battery), .reading(.workingStatus)]))

        // Sensors (read-only)
        add(["Motion Sensor", "PIR Motion Sensor"],
            DeviceProfile(symbolName: "sensor", category: .sensors,
                          capabilities: [.reading(.moveDetected), .reading(.battery)]))
        add(["Contact Sensor"],
            DeviceProfile(symbolName: "door.left.hand.open", category: .sensors,
                          capabilities: [.reading(.openState), .reading(.battery)]))
        add(["Water Leak Detector"],
            DeviceProfile(symbolName: "drop.triangle", category: .sensors,
                          capabilities: [.reading(.detectionState), .reading(.battery)]))

        // Infrared / remotes — no status endpoint exists for these at all.
        add(["Air Conditioner"],
            DeviceProfile(symbolName: "air.conditioner.horizontal", category: .remotes,
                          capabilities: [.irPower, .irCustomize], hasStatusEndpoint: false))
        add(["TV", "DVD", "Set Top Box", "Speaker", "Fan", "Light", "IPTV/Streamer",
             "Projector", "Air Purifier IR", "Camera", "Others"],
            DeviceProfile(symbolName: "sparkles.tv", category: .remotes,
                          capabilities: [.irPower, .irCustomize], hasStatusEndpoint: false))

        return entries
    }()

    static func profile(for deviceType: String, kind: DeviceKind) -> DeviceProfile? {
        let key = normalize(deviceType)
        if let exact = table[key] { return exact }

        // Longest-prefix match: lets "Robot Vacuum Cleaner S20 Pro" resolve
        // against a table entry for "Robot Vacuum Cleaner S20", etc.
        let candidate = table.keys
            .filter { key.hasPrefix($0) || $0.hasPrefix(key) }
            .max(by: { $0.count < $1.count })
        if let candidate { return table[candidate] }

        // Unknown IR remote types still shouldn't get status-polled.
        if kind == .infrared {
            return DeviceProfile(symbolName: "sparkles.tv", category: .remotes,
                                  capabilities: [.irPower, .irCustomize], hasStatusEndpoint: false)
        }
        return nil
    }
}
