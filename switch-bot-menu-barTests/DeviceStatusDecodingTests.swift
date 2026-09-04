//
//  DeviceStatusDecodingTests.swift
//  switch-bot-menu-barTests
//
//  Table-driven over one fixture per device family, proving DeviceStatus
//  never throws on an unknown type and lenient accessors coerce values
//  correctly regardless of the JSON encoding SwitchBot happened to use.
//

import Foundation
import Testing
@testable import switch_bot_menu_bar

struct DeviceStatusDecodingTests {

    private func loadFixture(_ name: String) throws -> DeviceStatus {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures/\(name).json")
        let data = try Data(contentsOf: url)
        let envelope = try JSONDecoder().decode(APIEnvelope<DeviceStatus>.self, from: data)
        return try envelope.unwrap()
    }

    @Test func decodesBotStatus() throws {
        let status = try loadFixture("bot_status")
        #expect(status.deviceType == "Bot")
        #expect(status.power == .off)
        #expect(status.battery == 88)
    }

    @Test func decodesMeterStatusWithFloatingPointTemperature() throws {
        let status = try loadFixture("meter_status")
        #expect(status.temperature == 22.5)
        #expect(status.humidity == 48)
    }

    /// The central promise of the raw-bag model: an entirely unknown
    /// deviceType and an unmodeled nested field must not fail decoding,
    /// and lenient accessors still coerce string-encoded numbers.
    @Test func unknownDeviceTypeDecodesWithoutThrowing() throws {
        let status = try loadFixture("unknown_device_status")
        #expect(status.deviceType == "Future Gadget 3000")
        #expect(status.power == .on) // "ON" lowercased -> .on
        #expect(status.brightness == 50) // "50" string coerced to Int
        #expect(status.raw["someNewField"] != nil)
    }
}
