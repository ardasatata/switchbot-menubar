//
//  Device.swift
//  switch-bot-menu-bar
//

import Foundation

enum DeviceKind: String, Codable, Sendable {
    case physical
    case infrared
}

/// Unifies `deviceList` and `infraredRemoteList` entries from
/// `GET /v1.1/devices` into a single value type the rest of the app works with.
struct Device: Identifiable, Codable, Sendable, Hashable {
    let id: String              // deviceId
    var name: String            // deviceName
    let deviceType: String      // e.g. "Bot", "Plug Mini (US)", "Air Conditioner"
    let kind: DeviceKind
    let hubDeviceId: String?
    let enableCloudService: Bool?

    private enum CodingKeys: String, CodingKey {
        case id = "deviceId"
        case name = "deviceName"
        case deviceType, kind, hubDeviceId, enableCloudService
    }

    init(id: String, name: String, deviceType: String, kind: DeviceKind,
         hubDeviceId: String?, enableCloudService: Bool?) {
        self.id = id
        self.name = name
        self.deviceType = deviceType
        self.kind = kind
        self.hubDeviceId = hubDeviceId
        self.enableCloudService = enableCloudService
    }
}

/// Raw shape of `GET /v1.1/devices`'s `body` field.
struct DeviceListBody: Decodable, Sendable {
    let deviceList: [PhysicalDeviceDTO]
    let infraredRemoteList: [InfraredDeviceDTO]

    struct PhysicalDeviceDTO: Decodable, Sendable {
        let deviceId: String
        let deviceName: String
        let deviceType: String
        let hubDeviceId: String?
        let enableCloudService: Bool?
    }

    struct InfraredDeviceDTO: Decodable, Sendable {
        let deviceId: String
        let deviceName: String
        let remoteType: String
        let hubDeviceId: String?
    }

    var devices: [Device] {
        let physical = deviceList.map {
            Device(id: $0.deviceId, name: $0.deviceName, deviceType: $0.deviceType,
                   kind: .physical, hubDeviceId: $0.hubDeviceId,
                   enableCloudService: $0.enableCloudService)
        }
        let infrared = infraredRemoteList.map {
            Device(id: $0.deviceId, name: $0.deviceName, deviceType: $0.remoteType,
                   kind: .infrared, hubDeviceId: $0.hubDeviceId,
                   enableCloudService: nil)
        }
        return physical + infrared
    }
}
