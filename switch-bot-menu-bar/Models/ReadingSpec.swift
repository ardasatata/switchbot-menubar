//
//  ReadingSpec.swift
//  switch-bot-menu-bar
//
//  Read-only sensor rows are data, not view code: given a StatusKey this
//  describes how to label, icon, and format the value.
//

import Foundation

struct ReadingSpec: Sendable {
    let key: StatusKey
    let label: String
    let symbolName: String
    let format: @Sendable (DeviceStatus) -> String?

    static let all: [ReadingSpec] = [
        ReadingSpec(key: .temperature, label: "Temperature", symbolName: "thermometer.medium") {
            guard let value = $0.temperature else { return nil }
            return String(format: "%.1f°C", value)
        },
        ReadingSpec(key: .humidity, label: "Humidity", symbolName: "humidity") {
            guard let value = $0.humidity else { return nil }
            return "\(value)%"
        },
        ReadingSpec(key: .battery, label: "Battery", symbolName: "battery.100") {
            guard let value = $0.battery else { return nil }
            return "\(value)%"
        },
        ReadingSpec(key: .openState, label: "Contact", symbolName: "door.left.hand.open") {
            guard let open = $0.isSensorContactOpen else { return nil }
            return open ? "Open" : "Closed"
        },
        ReadingSpec(key: .detectionState, label: "Leak", symbolName: "drop.triangle") {
            guard let leak = $0.isLeakDetected else { return nil }
            return leak ? "Leak detected" : "Dry"
        },
        ReadingSpec(key: .moveDetected, label: "Motion", symbolName: "figure.walk.motion") {
            guard let detected = $0.bool(.moveDetected) else { return nil }
            return detected ? "Motion detected" : "Clear"
        },
        ReadingSpec(key: .pm25Value, label: "PM2.5", symbolName: "aqi.medium") {
            guard let value = $0.pm25 else { return nil }
            return "\(value) µg/m³"
        },
        ReadingSpec(key: .workingStatus, label: "Status", symbolName: "info.circle") {
            $0.workingStatus?.capitalized
        },
    ]

    static func spec(for key: StatusKey) -> ReadingSpec? {
        all.first { $0.key == key }
    }
}

extension ReadingSpec: Equatable {
    static func == (lhs: ReadingSpec, rhs: ReadingSpec) -> Bool { lhs.key == rhs.key }
}
