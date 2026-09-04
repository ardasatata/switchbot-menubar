//
//  DeviceCommand.swift
//  switch-bot-menu-bar
//

import Foundation

/// The literal request body for `POST /v1.1/devices/{id}/commands`.
/// Decodable too, so DemoHTTPClient can inspect a command it's asked to send.
struct DeviceCommand: Codable, Sendable, Equatable {
    let command: String
    let parameter: JSONValue
    let commandType: String

    static func == (lhs: DeviceCommand, rhs: DeviceCommand) -> Bool {
        lhs.command == rhs.command && lhs.parameter == rhs.parameter && lhs.commandType == rhs.commandType
    }

    /// Maps a user intent to the exact command SwitchBot expects for this
    /// device, consulting DeviceQuirks only for genuine per-type parameter
    /// format divergences (Curtain vs Roller Shade vs Vacuum families, etc).
    static func make(intent: ControlIntent, for device: Device) -> DeviceCommand {
        let quirk = DeviceQuirks.quirk(for: device.deviceType)

        switch intent {
        case .turnOn:
            return DeviceCommand(command: "turnOn", parameter: "default", commandType: "command")
        case .turnOff:
            return DeviceCommand(command: "turnOff", parameter: "default", commandType: "command")
        case .toggle:
            return DeviceCommand(command: "toggle", parameter: "default", commandType: "command")
        case .press:
            return DeviceCommand(command: "press", parameter: "default", commandType: "command")

        case .setBrightness(let value):
            return DeviceCommand(command: "setBrightness", parameter: JSONValue.string("\(value)"), commandType: "command")

        case .setColorRGB(let r, let g, let b):
            return DeviceCommand(command: "setColor", parameter: JSONValue.string("\(r):\(g):\(b)"), commandType: "command")

        case .setColorTemperature(let kelvin):
            return DeviceCommand(command: "setColorTemperature", parameter: JSONValue.string("\(kelvin)"), commandType: "command")

        case .setPosition(let value):
            return quirk.positionCommand(value)

        case .setFanSpeed(let value):
            return DeviceCommand(command: "setWindSpeed", parameter: JSONValue.string("\(value)"), commandType: "command")

        case .setMode(let mode):
            return DeviceCommand(command: "setMode", parameter: JSONValue.string(mode), commandType: "command")

        case .lock:
            return DeviceCommand(command: "lock", parameter: "default", commandType: "command")
        case .unlock:
            return DeviceCommand(command: "unlock", parameter: "default", commandType: "command")

        case .vacuumStart:
            return quirk.vacuumStartCommand()
        case .vacuumStop:
            return DeviceCommand(command: "stop", parameter: "default", commandType: "command")
        case .vacuumDock:
            return DeviceCommand(command: "dock", parameter: "default", commandType: "command")

        case .irButton(let name):
            // Standard on/off buttons on IR devices are "command" type;
            // any other user-defined button is "customize".
            if name == "turnOn" || name == "turnOff" {
                return DeviceCommand(command: name, parameter: "default", commandType: "command")
            }
            return DeviceCommand(command: name, parameter: "default", commandType: "customize")
        }
    }
}
