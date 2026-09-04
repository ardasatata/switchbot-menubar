//
//  DeviceStatus.swift
//  switch-bot-menu-bar
//
//  Modeled as a typed envelope over a raw JSONValue bag rather than per-type
//  Codable structs: SwitchBot ships new device types and status fields
//  continuously, and a strict decoder would fail the whole refresh on an
//  unknown one. See DeviceStatus+Readings.swift for lenient typed accessors.
//

import Foundation

struct DeviceStatus: Sendable, Equatable {
    let deviceId: String
    let deviceType: String
    let hubDeviceId: String?
    let raw: [String: JSONValue]
    let fetchedAt: Date

    static func == (lhs: DeviceStatus, rhs: DeviceStatus) -> Bool {
        lhs.deviceId == rhs.deviceId && lhs.raw == rhs.raw
    }
}

extension DeviceStatus: Decodable {
    private enum CodingKeys: String, CodingKey {
        case deviceId, deviceType, hubDeviceId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        deviceType = try container.decode(String.self, forKey: .deviceType)
        hubDeviceId = try container.decodeIfPresent(String.self, forKey: .hubDeviceId)

        // Decode the entire payload a second time as a flat bag so every
        // field — known or not — survives into `raw`.
        let single = try decoder.singleValueContainer()
        if let object = try? single.decode([String: JSONValue].self) {
            raw = object
        } else {
            raw = [:]
        }
        fetchedAt = Date()
    }
}

extension DeviceStatus: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(JSONValue.object(raw))
    }
}
