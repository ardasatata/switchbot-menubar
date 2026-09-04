//
//  DeviceQuirks.swift
//  switch-bot-menu-bar
//
//  A handful of device families encode command parameters differently from
//  the "default" / plain-number convention most devices use. This isolates
//  those differences so DeviceCommand.make(intent:for:) stays a straight
//  intent -> capability mapping.
//

import Foundation

struct DeviceQuirks: Sendable {
    let positionCommand: @Sendable (Int) -> DeviceCommand
    let vacuumStartCommand: @Sendable () -> DeviceCommand

    static let standard = DeviceQuirks(
        positionCommand: { value in
            DeviceCommand(command: "setPosition", parameter: JSONValue.string("\(value)"), commandType: "command")
        },
        vacuumStartCommand: {
            DeviceCommand(command: "start", parameter: "default", commandType: "command")
        }
    )

    /// Curtain / Curtain 3: "index,mode,position" — a single curtain uses
    /// index 0, mode 0xFF (performance mode), and the target 0-100 position.
    static let curtain = DeviceQuirks(
        positionCommand: { value in
            DeviceCommand(command: "setPosition", parameter: JSONValue.string("0,ff,\(value)"), commandType: "command")
        },
        vacuumStartCommand: standard.vacuumStartCommand
    )

    /// Blind Tilt: same "index,mode,position" shape, but positions must be
    /// even; round to the nearest even value defensively.
    static let blindTilt = DeviceQuirks(
        positionCommand: { value in
            let rounded = value - (value % 2)
            return DeviceCommand(command: "setPosition", parameter: JSONValue.string("0,up,\(rounded)"), commandType: "command")
        },
        vacuumStartCommand: standard.vacuumStartCommand
    )

    /// Robot Vacuum S10/S20/K-series: `startClean` takes a nested object
    /// parameter rather than the S1 family's bare `start` command.
    static let vacuumStartClean = DeviceQuirks(
        positionCommand: standard.positionCommand,
        vacuumStartCommand: {
            DeviceCommand(
                command: "startClean",
                parameter: JSONValue.object([
                    "action": "sweep",
                    "param": JSONValue.object([
                        "fanLevel": 1,
                        "waterLevel": 1,
                        "times": 1,
                    ]),
                ]),
                commandType: "command"
            )
        }
    )

    /// Exact normalized deviceTypes that use the S1 family's plain
    /// `start`/`stop`/`dock` commands rather than `startClean`. Deliberately
    /// an exact-match set, not a prefix check: "robot vacuum cleaner s1"
    /// is itself a prefix of "robot vacuum cleaner s10", so a naive prefix
    /// exclusion would misclassify S10/S20 as S1-family.
    private static let vacuumS1Family: Set<String> = [
        "robot vacuum cleaner s1",
        "robot vacuum cleaner s1 plus",
    ]

    static func quirk(for deviceType: String) -> DeviceQuirks {
        let normalized = DeviceCatalog.normalize(deviceType)
        if normalized.hasPrefix("curtain") {
            return .curtain
        }
        if normalized.hasPrefix("blind tilt") {
            return .blindTilt
        }
        if normalized.hasPrefix("robot vacuum cleaner") {
            // S10/S20/K-series use startClean; S1/S1 Plus use plain start.
            return vacuumS1Family.contains(normalized) ? .standard : .vacuumStartClean
        }
        return .standard
    }
}
