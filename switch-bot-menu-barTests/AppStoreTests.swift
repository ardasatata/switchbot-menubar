//
//  AppStoreTests.swift
//  switch-bot-menu-barTests
//

import Foundation
import Testing
@testable import switch_bot_menu_bar

@MainActor
struct AppStoreTests {

    private static let devicesJSON = """
    {"statusCode": 100, "message": "success", "body": {
        "deviceList": [
            {"deviceId": "bot-1", "deviceName": "Bot", "deviceType": "Bot", "hubDeviceId": "hub-1", "enableCloudService": true}
        ],
        "infraredRemoteList": []
    }}
    """

    private func statusJSON(power: String) -> String {
        """
        {"statusCode": 100, "message": "success", "body": {
            "deviceId": "bot-1", "deviceType": "Bot", "power": "\(power)", "battery": 80
        }}
        """
    }

    private func makeStore(stub: StubHTTPClient, credentials: SwitchBotCredentials = .init(token: "t", secret: "s")) -> AppStore {
        AppStore(
            credentialStore: InMemoryCredentialStore(initial: credentials),
            diskCache: DiskCache(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")),
            httpClientFactory: { stub }
        )
    }

    @Test func startLoadsDevicesWithoutFetchingStatusYet() async {
        let stub = StubHTTPClient()
        await stub.queue(path: "/v1.1/devices", json: Self.devicesJSON)
        await stub.queue(path: "/v1.1/scenes", json: #"{"statusCode":100,"message":"success","body":[]}"#)

        let store = makeStore(stub: stub)
        await store.start()

        #expect(store.devices.count == 1)
        #expect(await stub.callCount(forPath: "/v1.1/devices/bot-1/status") == 0)
    }

    @Test func refreshOnOpenFetchesStatusOnceThenSkipsWithinTTL() async {
        let stub = StubHTTPClient()
        await stub.queue(path: "/v1.1/devices", json: Self.devicesJSON)
        await stub.queue(path: "/v1.1/scenes", json: #"{"statusCode":100,"message":"success","body":[]}"#)
        await stub.setDefault(json: statusJSON(power: "off"))

        let store = makeStore(stub: stub)
        await store.start()
        await store.refreshOnOpen()
        #expect(await stub.callCount(forPath: "/v1.1/devices/bot-1/status") == 1)

        // Second refresh within the 60s TTL should not issue another call —
        // this is what protects the 10,000/day budget.
        await store.refreshOnOpen()
        #expect(await stub.callCount(forPath: "/v1.1/devices/bot-1/status") == 1)
    }

    @Test func sendIntentAppliesOptimisticStateImmediately() async {
        let stub = StubHTTPClient()
        await stub.queue(path: "/v1.1/devices", json: Self.devicesJSON)
        await stub.queue(path: "/v1.1/scenes", json: #"{"statusCode":100,"message":"success","body":[]}"#)
        await stub.setDefault(json: statusJSON(power: "off"))

        let store = makeStore(stub: stub)
        await store.start()
        await store.refreshOnOpen()

        let device = store.devices[0]
        // Queue the command success + a confirmation status fetch.
        await stub.queue(path: "/v1.1/devices/bot-1/commands", json: #"{"statusCode":100,"message":"success","body":{}}"#)
        await stub.queue(path: "/v1.1/devices/bot-1/status", json: statusJSON(power: "on"))

        await store.send(.turnOn, to: device)

        #expect(store.effectiveStatus(for: device.id)?.power == .on)
        #expect(await stub.callCount(forPath: "/v1.1/devices/bot-1/commands") == 1)
    }

    @Test func sendIntentRevertsOptimisticStateOnError() async {
        let stub = StubHTTPClient()
        await stub.queue(path: "/v1.1/devices", json: Self.devicesJSON)
        await stub.queue(path: "/v1.1/scenes", json: #"{"statusCode":100,"message":"success","body":[]}"#)
        await stub.setDefault(json: statusJSON(power: "off"))

        let store = makeStore(stub: stub)
        await store.start()
        await store.refreshOnOpen()

        let device = store.devices[0]
        await stub.queue(path: "/v1.1/devices/bot-1/commands", json: #"{"statusCode":161,"message":"device offline","body":{}}"#)

        await store.send(.turnOn, to: device)

        #expect(store.effectiveStatus(for: device.id)?.power == .off)
        #expect(store.lastError == .deviceOffline)
    }

    @Test func infraredDevicesAreNeverStatusPolled() async {
        let json = """
        {"statusCode": 100, "message": "success", "body": {
            "deviceList": [],
            "infraredRemoteList": [
                {"deviceId": "ac-1", "deviceName": "Bedroom AC", "remoteType": "Air Conditioner", "hubDeviceId": "hub-1"}
            ]
        }}
        """
        let stub = StubHTTPClient()
        await stub.queue(path: "/v1.1/devices", json: json)
        await stub.queue(path: "/v1.1/scenes", json: #"{"statusCode":100,"message":"success","body":[]}"#)

        let store = makeStore(stub: stub)
        await store.start()
        await store.refreshOnOpen()

        #expect(await stub.callCount(forPath: "/v1.1/devices/ac-1/status") == 0)
    }

    @Test func unknownDeviceTypeStillGetsInferredCapabilitiesFromRawStatus() async {
        let json = """
        {"statusCode": 100, "message": "success", "body": {
            "deviceList": [
                {"deviceId": "x-1", "deviceName": "Mystery Device", "deviceType": "Brand New SKU", "hubDeviceId": "hub-1", "enableCloudService": true}
            ],
            "infraredRemoteList": []
        }}
        """
        let stub = StubHTTPClient()
        await stub.queue(path: "/v1.1/devices", json: json)
        await stub.queue(path: "/v1.1/scenes", json: #"{"statusCode":100,"message":"success","body":[]}"#)
        await stub.setDefault(json: #"{"statusCode":100,"message":"success","body":{"deviceId":"x-1","deviceType":"Brand New SKU","power":"on","brightness":40}}"#)

        let store = makeStore(stub: stub)
        await store.start()
        await store.refreshOnOpen()

        let device = store.devices[0]
        let capabilities = store.effectiveCapabilities(for: device)
        #expect(capabilities.contains(.power))
        #expect(capabilities.contains(.brightness(1...100)))
    }
}
