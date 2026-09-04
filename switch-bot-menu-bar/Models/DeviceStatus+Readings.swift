//
//  DeviceStatus+Readings.swift
//  switch-bot-menu-bar
//
//  Typed, lenient accessors over DeviceStatus.raw. StatusKey is a raw-String
//  enum so field names used across the app (readings, capability inference,
//  command building) are typo-proof and centrally documented.
//

import Foundation

enum StatusKey: String, Sendable, CaseIterable {
    case power                     // "on" / "off" — Bot, Plug, Bulb, Strip, Relay, Fan, Humidifier...
    case moveDetected
    case brightness                // Bulb, Strip, Ceiling Light
    case color                     // "R:G:B"
    case colorTemperature
    case slidePosition             // Curtain, Roller Shade (0-100)
    case direction                 // Blind Tilt: "up"/"down"
    case lockState                 // "locked" / "unlocked" / "jammed"
    case doorOpen                  // deadbolt-style locks
    case calibrate
    case battery                   // Meter, Lock, Bot, Vacuum (0-100)
    case temperature               // Meter, Meter Plus, thermostat-ish
    case humidity                  // Meter, Humidifier
    case nebulizationEfficiency    // Humidifier
    case waterLevel
    case workingStatus             // Robot Vacuum
    case onlineStatus
    case openState                 // Contact Sensor: "open"/"close"/"timeOutNotClose"
    case detectionState             // Water Leak: "0" no leak / "1" leak
    case fanSpeed
    case mode
    case deviceMode                // Bot: "pressMode" / "switchMode" / "customizeMode"
    case pm25Value                 // Air Purifier
    case airQualityLevel
}

enum PowerState: String, Sendable {
    case on
    case off
}

extension DeviceStatus {
    func value(_ key: StatusKey) -> JSONValue? { raw[key.rawValue] }
    func int(_ key: StatusKey) -> Int? { raw.int(key.rawValue) }
    func double(_ key: StatusKey) -> Double? { raw.double(key.rawValue) }
    func string(_ key: StatusKey) -> String? { raw.string(key.rawValue) }
    func bool(_ key: StatusKey) -> Bool? { raw.bool(key.rawValue) }

    var power: PowerState? {
        string(.power).flatMap { PowerState(rawValue: $0.lowercased()) }
    }

    var brightness: Int? { int(.brightness) }
    var colorTemperatureKelvin: Int? { int(.colorTemperature) }
    var battery: Int? { int(.battery) }
    var temperature: Double? { double(.temperature) }
    var humidity: Int? { int(.humidity) }
    var slidePosition: Int? { int(.slidePosition) }
    var lockState: String? { string(.lockState) }
    var workingStatus: String? { string(.workingStatus) }
    var pm25: Int? { int(.pm25Value) }

    /// "R:G:B" -> (r, g, b) each 0-255.
    var colorRGB: (r: Int, g: Int, b: Int)? {
        guard let raw = string(.color) else { return nil }
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return (parts[0], parts[1], parts[2])
    }

    var isSensorContactOpen: Bool? {
        guard let value = string(.openState) else { return nil }
        return value.lowercased() == "open"
    }

    var isLeakDetected: Bool? {
        guard let value = string(.detectionState) else { return nil }
        return value == "1"
    }
}
