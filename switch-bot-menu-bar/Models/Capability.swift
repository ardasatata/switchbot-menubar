//
//  Capability.swift
//  switch-bot-menu-bar
//
//  The control vocabulary. Views render controls by iterating a device's
//  capabilities — there is deliberately no per-device-type switch anywhere
//  in the view layer. See Services/DeviceCatalog.swift for how a deviceType
//  string maps to a capability set, including the raw-status inference
//  fallback that covers device types not in the static table.
//

import Foundation

enum PositionStyle: Sendable, Hashable {
    case curtain
    case blindTilt
    case rollerShade
}

enum Capability: Sendable, Hashable {
    case power
    case press                                     // Bot in "press" deviceMode
    case lock
    case vacuum
    case brightness(ClosedRange<Int>)
    case colorRGB
    case colorTemperature(ClosedRange<Int>)
    case position(PositionStyle)
    case fanSpeed(levels: Int)
    case mode([String])
    case irPower                                   // AC / generic IR turnOn/turnOff
    case irCustomize                                // user-defined IR buttons
    case reading(StatusKey)

    /// A stable sort key so a device's controls render in a sensible,
    /// consistent order regardless of the order they were inferred/looked up.
    var sortRank: Int {
        switch self {
        case .power: return 0
        case .press: return 0
        case .lock: return 1
        case .vacuum: return 1
        case .position: return 2
        case .brightness: return 3
        case .colorTemperature: return 4
        case .colorRGB: return 5
        case .fanSpeed: return 6
        case .mode: return 7
        case .irPower: return 0
        case .irCustomize: return 8
        case .reading: return 100
        }
    }
}

/// Where a device sits in the menu's grouped list.
enum DeviceCategory: String, Sendable, CaseIterable {
    case lighting = "Lighting"
    case plugs = "Plugs & Switches"
    case climate = "Climate"
    case coverings = "Curtains & Blinds"
    case security = "Locks & Security"
    case cleaning = "Cleaning"
    case sensors = "Sensors"
    case remotes = "Remotes"
    case other = "Other"
}
