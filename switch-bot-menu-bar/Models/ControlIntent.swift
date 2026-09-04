//
//  ControlIntent.swift
//  switch-bot-menu-bar
//
//  What the user asked to happen. DeviceCommand.make(intent:device:) turns
//  this into the actual SwitchBot request body, consulting DeviceQuirks only
//  for the handful of devices whose parameter format genuinely diverges.
//

import Foundation

enum ControlIntent: Sendable, Equatable {
    case turnOn
    case turnOff
    case toggle
    case press
    case setBrightness(Int)                // 1-100
    case setColorRGB(r: Int, g: Int, b: Int)
    case setColorTemperature(Int)          // Kelvin
    case setPosition(Int)                  // 0-100
    case setFanSpeed(Int)
    case setMode(String)
    case lock
    case unlock
    case vacuumStart
    case vacuumStop
    case vacuumDock
    case irButton(String)                  // customize command name
}
