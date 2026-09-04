//
//  DeviceCatalogTests.swift
//  switch-bot-menu-barTests
//

import Foundation
import Testing
@testable import switch_bot_menu_bar

struct DeviceCatalogTests {

    @Test(arguments: [
        "Bot", "Plug", "Plug Mini (US)", "Plug Mini (JP)", "Color Bulb", "Strip Light",
        "Ceiling Light", "Curtain", "Curtain 3", "Blind Tilt", "Roller Shade",
        "Lock Pro", "Robot Vacuum Cleaner S1", "Robot Vacuum Cleaner S10",
        "Meter", "Meter Plus", "Motion Sensor", "Contact Sensor", "Water Leak Detector",
        "Air Conditioner",
    ])
    func everyKnownDeviceTypeResolvesToAProfile(deviceType: String) {
        let kind: DeviceKind = deviceType == "Air Conditioner" ? .infrared : .physical
        #expect(DeviceCatalog.profile(for: deviceType, kind: kind) != nil)
    }

    @Test func regionalSuffixesResolveToTheSameProfileAsTheBaseType() {
        let us = DeviceCatalog.profile(for: "Plug Mini (US)", kind: .physical)
        let jp = DeviceCatalog.profile(for: "Plug Mini (JP)", kind: .physical)
        #expect(us?.category == jp?.category)
        #expect(us?.symbolName == jp?.symbolName)
    }

    @Test func infraredRemotesNeverClaimAStatusEndpoint() {
        let profile = DeviceCatalog.profile(for: "Air Conditioner", kind: .infrared)
        #expect(profile?.hasStatusEndpoint == false)
    }

    @Test func unknownInfraredTypeStillGetsAFallbackProfileWithNoStatusEndpoint() {
        let profile = DeviceCatalog.profile(for: "Some Brand New Remote", kind: .infrared)
        #expect(profile != nil)
        #expect(profile?.hasStatusEndpoint == false)
    }

    @Test func unknownPhysicalTypeHasNoStaticProfile() {
        // AppStore.effectiveCapabilities covers this case via raw-status
        // inference (see AppStoreTests); the catalog itself is honest that
        // it doesn't know this type.
        let profile = DeviceCatalog.profile(for: "Some Brand New Sensor", kind: .physical)
        #expect(profile == nil)
    }

    @Test func normalizeStripsRegionSuffixAndLowercases() {
        #expect(DeviceCatalog.normalize("Plug Mini (US)") == "plug mini")
        #expect(DeviceCatalog.normalize("Plug Mini (JP)") == "plug mini")
        #expect(DeviceCatalog.normalize("Bot") == "bot")
    }
}
