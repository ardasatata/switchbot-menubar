//
//  DemoHTTPClient.swift
//  switch-bot-menu-bar
//
//  A fixture-backed HTTPClient conforming to the exact same protocol
//  SwitchBotClient depends on for real traffic, so "Demo Mode" is not a
//  separate code path through the app — only a different HTTPClient wired
//  into the same AppStore. It lets App Review (and prospective users with
//  no SwitchBot account yet) exercise every control with no credentials
//  and no network access. Commands mutate in-memory state so toggles,
//  sliders, and colors visibly respond rather than reading as broken.
//

import Foundation

actor DemoDeviceState {
    static let shared = DemoDeviceState()

    private(set) var devices: [Device]
    private var statuses: [String: [String: JSONValue]]
    private(set) var scenes: [SceneItem]

    private init() {
        devices = [
            Device(id: "demo-bot", name: "Coffee Machine", deviceType: "Bot", kind: .physical, hubDeviceId: "demo-hub", enableCloudService: true),
            Device(id: "demo-plug", name: "Desk Lamp Plug", deviceType: "Plug Mini (US)", kind: .physical, hubDeviceId: "demo-hub", enableCloudService: true),
            Device(id: "demo-bulb", name: "Living Room Bulb", deviceType: "Color Bulb", kind: .physical, hubDeviceId: nil, enableCloudService: true),
            Device(id: "demo-strip", name: "TV Backlight", deviceType: "Strip Light", kind: .physical, hubDeviceId: nil, enableCloudService: true),
            Device(id: "demo-curtain", name: "Bedroom Curtain", deviceType: "Curtain 3", kind: .physical, hubDeviceId: "demo-hub", enableCloudService: true),
            Device(id: "demo-lock", name: "Front Door Lock", deviceType: "Lock Pro", kind: .physical, hubDeviceId: "demo-hub", enableCloudService: true),
            Device(id: "demo-meter", name: "Office Meter", deviceType: "Meter Plus", kind: .physical, hubDeviceId: "demo-hub", enableCloudService: true),
            Device(id: "demo-vacuum", name: "Living Room Vacuum", deviceType: "Robot Vacuum Cleaner S10", kind: .physical, hubDeviceId: nil, enableCloudService: true),
            Device(id: "demo-contact", name: "Front Door Sensor", deviceType: "Contact Sensor", kind: .physical, hubDeviceId: "demo-hub", enableCloudService: true),
            Device(id: "demo-ir-ac", name: "Bedroom AC", deviceType: "Air Conditioner", kind: .infrared, hubDeviceId: "demo-hub", enableCloudService: nil),
        ]

        statuses = [
            "demo-bot": ["power": .string("off"), "battery": .number(88), "deviceMode": .string("switchMode")],
            "demo-plug": ["power": .string("on")],
            "demo-bulb": ["power": .string("on"), "brightness": .number(75), "color": .string("255:180:80"), "colorTemperature": .number(4000)],
            "demo-strip": ["power": .string("off"), "brightness": .number(50), "color": .string("80:120:255")],
            "demo-curtain": ["slidePosition": .number(40), "battery": .number(64)],
            "demo-lock": ["lockState": .string("locked"), "battery": .number(71)],
            "demo-meter": ["temperature": .number(22.5), "humidity": .number(48), "battery": .number(90)],
            "demo-vacuum": ["battery": .number(76), "workingStatus": .string("standby")],
            "demo-contact": ["openState": .string("close"), "battery": .number(95)],
        ]

        scenes = [
            SceneItem(id: "demo-scene-movie", name: "Movie Night"),
            SceneItem(id: "demo-scene-morning", name: "Good Morning"),
        ]
    }

    func status(for deviceId: String) -> [String: JSONValue]? {
        statuses[deviceId]
    }

    func device(for deviceId: String) -> Device? {
        devices.first { $0.id == deviceId }
    }

    /// Applies a command's effect to the in-memory fixture and returns
    /// whether the deviceId is recognized (false -> statusCode 152 upstream).
    func apply(command: DeviceCommand, to deviceId: String) -> Bool {
        guard var status = statuses[deviceId] else { return false }

        switch command.command {
        case "turnOn": status["power"] = .string("on")
        case "turnOff": status["power"] = .string("off")
        case "toggle":
            let isOn = status["power"]?.asString == "on"
            status["power"] = .string(isOn ? "off" : "on")
        case "press":
            break // momentary — no persisted state change
        case "setBrightness":
            if let value = command.parameter.asInt { status["brightness"] = .number(Double(value)) }
        case "setColor":
            if let value = command.parameter.asString { status["color"] = .string(value) }
        case "setColorTemperature":
            if let value = command.parameter.asInt { status["colorTemperature"] = .number(Double(value)) }
        case "setPosition":
            if let raw = command.parameter.asString {
                let numeric = raw.split(separator: ",").last.flatMap { Int($0) } ?? Int(raw)
                if let numeric { status["slidePosition"] = .number(Double(numeric)) }
            }
        case "lock": status["lockState"] = .string("locked")
        case "unlock": status["lockState"] = .string("unlocked")
        case "start", "startClean": status["workingStatus"] = .string("cleaning")
        case "stop": status["workingStatus"] = .string("standby")
        case "dock": status["workingStatus"] = .string("docking")
        default:
            break
        }

        statuses[deviceId] = status
        return true
    }
}

struct DemoHTTPClient: HTTPClient {
    private let state = DemoDeviceState.shared

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // Simulate realistic latency so loading states are visible.
        try? await Task.sleep(for: .milliseconds(300))

        guard let url = request.url else {
            return try envelope(statusCode: 190, message: "bad request")
        }
        let path = url.path

        if path == "/v1.1/devices" {
            let devices = await state.devices
            return try devicesEnvelope(devices)
        }

        if path == "/v1.1/scenes" {
            let scenes = await state.scenes
            return try scenesEnvelope(scenes)
        }

        if let sceneId = pathComponent(path, matching: #"^/v1\.1/scenes/([^/]+)/execute$"#) {
            _ = sceneId
            return try envelope(statusCode: 100, message: "success")
        }

        if let deviceId = pathComponent(path, matching: #"^/v1\.1/devices/([^/]+)/status$"#) {
            guard let raw = await state.status(for: deviceId),
                  let device = await state.device(for: deviceId) else {
                return try envelope(statusCode: 152, message: "device not found")
            }
            return try statusEnvelope(deviceId: deviceId, deviceType: device.deviceType, raw: raw)
        }

        if let deviceId = pathComponent(path, matching: #"^/v1\.1/devices/([^/]+)/commands$"#) {
            guard let body = request.httpBody,
                  let command = try? JSONDecoder().decode(DeviceCommand.self, from: body) else {
                return try envelope(statusCode: 190, message: "bad command body")
            }
            let ok = await state.apply(command: command, to: deviceId)
            return try envelope(statusCode: ok ? 100 : 152, message: ok ? "success" : "device not found")
        }

        return try envelope(statusCode: 190, message: "unhandled demo route")
    }

    // MARK: - Response building

    private func httpResponse(for url: URL = SwitchBotClient.baseURL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    private func envelope(statusCode: Int, message: String) throws -> (Data, HTTPURLResponse) {
        let payload: [String: JSONValue] = ["statusCode": .number(Double(statusCode)), "message": .string(message), "body": .object([:])]
        return (try JSONEncoder().encode(JSONValue.object(payload)), httpResponse())
    }

    private func devicesEnvelope(_ devices: [Device]) throws -> (Data, HTTPURLResponse) {
        var deviceList: [JSONValue] = []
        var irList: [JSONValue] = []
        for device in devices {
            let entry: [String: JSONValue] = [
                "deviceId": .string(device.id),
                "deviceName": .string(device.name),
                (device.kind == .physical ? "deviceType" : "remoteType"): .string(device.deviceType),
                "hubDeviceId": device.hubDeviceId.map { .string($0) } ?? .null,
                "enableCloudService": device.enableCloudService.map { .bool($0) } ?? .bool(true),
            ]
            if device.kind == .physical { deviceList.append(.object(entry)) } else { irList.append(.object(entry)) }
        }
        let body: [String: JSONValue] = ["deviceList": .array(deviceList), "infraredRemoteList": .array(irList)]
        let payload: [String: JSONValue] = ["statusCode": 100, "message": "success", "body": .object(body)]
        return (try JSONEncoder().encode(JSONValue.object(payload)), httpResponse())
    }

    private func scenesEnvelope(_ scenes: [SceneItem]) throws -> (Data, HTTPURLResponse) {
        let array: [JSONValue] = scenes.map { .object(["sceneId": .string($0.id), "sceneName": .string($0.name)]) }
        let payload: [String: JSONValue] = ["statusCode": 100, "message": "success", "body": .array(array)]
        return (try JSONEncoder().encode(JSONValue.object(payload)), httpResponse())
    }

    private func statusEnvelope(deviceId: String, deviceType: String, raw: [String: JSONValue]) throws -> (Data, HTTPURLResponse) {
        var body = raw
        body["deviceId"] = .string(deviceId)
        body["deviceType"] = .string(deviceType)
        let payload: [String: JSONValue] = ["statusCode": 100, "message": "success", "body": .object(body)]
        return (try JSONEncoder().encode(JSONValue.object(payload)), httpResponse())
    }

    private func pathComponent(_ path: String, matching pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
              let range = Range(match.range(at: 1), in: path) else {
            return nil
        }
        return String(path[range])
    }
}
