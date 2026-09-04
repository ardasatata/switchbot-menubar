//
//  DeviceCommandTests.swift
//  switch-bot-menu-barTests
//
//  Every ControlIntent, against both a standard device and the quirky
//  device families, must produce exactly the JSON body SwitchBot expects.
//

import Foundation
import Testing
@testable import switch_bot_menu_bar

struct DeviceCommandTests {

    private func device(type: String, kind: DeviceKind = .physical) -> Device {
        Device(id: "d1", name: "Test", deviceType: type, kind: kind, hubDeviceId: nil, enableCloudService: true)
    }

    @Test func turnOnProducesDefaultParameter() {
        let command = DeviceCommand.make(intent: .turnOn, for: device(type: "Plug Mini (US)"))
        #expect(command.command == "turnOn")
        #expect(command.parameter == .string("default"))
        #expect(command.commandType == "command")
    }

    @Test func setBrightnessEncodesValueAsString() {
        let command = DeviceCommand.make(intent: .setBrightness(75), for: device(type: "Color Bulb"))
        #expect(command.command == "setBrightness")
        #expect(command.parameter == .string("75"))
    }

    @Test func setColorRGBEncodesColonSeparatedTriple() {
        let command = DeviceCommand.make(intent: .setColorRGB(r: 255, g: 128, b: 0), for: device(type: "Color Bulb"))
        #expect(command.command == "setColor")
        #expect(command.parameter == .string("255:128:0"))
    }

    @Test func curtainPositionUsesIndexModePositionFormat() {
        let command = DeviceCommand.make(intent: .setPosition(40), for: device(type: "Curtain 3"))
        #expect(command.command == "setPosition")
        #expect(command.parameter == .string("0,ff,40"))
    }

    @Test func blindTiltPositionRoundsToEven() {
        let command = DeviceCommand.make(intent: .setPosition(41), for: device(type: "Blind Tilt"))
        #expect(command.parameter == .string("0,up,40"))
    }

    @Test func rollerShadePositionIsBareNumber() {
        let command = DeviceCommand.make(intent: .setPosition(60), for: device(type: "Roller Shade"))
        #expect(command.parameter == .string("60"))
    }

    @Test func vacuumS1FamilyUsesPlainStartCommand() {
        let command = DeviceCommand.make(intent: .vacuumStart, for: device(type: "Robot Vacuum Cleaner S1"))
        #expect(command.command == "start")
        #expect(command.parameter == .string("default"))
    }

    @Test func vacuumS10FamilyUsesStartCleanWithNestedObjectParameter() {
        let command = DeviceCommand.make(intent: .vacuumStart, for: device(type: "Robot Vacuum Cleaner S10"))
        #expect(command.command == "startClean")
        guard case .object(let parameter) = command.parameter else {
            Issue.record("expected object parameter")
            return
        }
        #expect(parameter["action"] == .string("sweep"))
        #expect(parameter["param"]?.asObject?["fanLevel"]?.asInt == 1)
    }

    @Test func lockAndUnlockProduceDedicatedCommands() {
        #expect(DeviceCommand.make(intent: .lock, for: device(type: "Lock Pro")).command == "lock")
        #expect(DeviceCommand.make(intent: .unlock, for: device(type: "Lock Pro")).command == "unlock")
    }

    @Test func standardTurnOnIRButtonUsesCommandType() {
        let command = DeviceCommand.make(intent: .irButton("turnOn"), for: device(type: "Air Conditioner", kind: .infrared))
        #expect(command.commandType == "command")
    }

    @Test func customUserDefinedIRButtonUsesCustomizeType() {
        let command = DeviceCommand.make(intent: .irButton("mySavedButton"), for: device(type: "TV", kind: .infrared))
        #expect(command.commandType == "customize")
        #expect(command.command == "mySavedButton")
    }
}
