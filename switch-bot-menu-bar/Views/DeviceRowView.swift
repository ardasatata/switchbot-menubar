//
//  DeviceRowView.swift
//  switch-bot-menu-bar
//
//  Generic: iterates the device's capabilities and renders a control per
//  capability. There is deliberately no per-device-type branching here —
//  adding support for a new SwitchBot device is a DeviceCatalog entry, not
//  a view edit.
//

import SwiftUI

struct DeviceRowView: View {
    let vm: DeviceViewModel

    private var primaryCapabilities: [Capability] {
        vm.capabilities.filter { if case .reading = $0 { return false }; return true }
    }

    private var readingCapabilities: [StatusKey] {
        vm.capabilities.compactMap { if case .reading(let key) = $0 { return key }; return nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: vm.symbolName)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)

                Text(vm.displayName)
                    .font(.body)
                    .lineLimit(1)

                Spacer()

                ForEach(Array(primaryCapabilities.filter(isCompact).enumerated()), id: \.offset) { _, capability in
                    control(for: capability)
                }

                Button {
                    vm.togglePin()
                } label: {
                    Image(systemName: vm.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(vm.isPinned ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
            }

            ForEach(Array(primaryCapabilities.filter { !isCompact($0) }.enumerated()), id: \.offset) { _, capability in
                control(for: capability)
            }

            if !readingCapabilities.isEmpty {
                HStack(spacing: 12) {
                    ForEach(readingCapabilities, id: \.self) { key in
                        ReadingRow(vm: vm, key: key)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Capabilities small enough to sit inline on the header row; anything
    /// wider (sliders) gets its own row below.
    private func isCompact(_ capability: Capability) -> Bool {
        switch capability {
        case .power, .press, .lock, .vacuum, .colorRGB, .irPower, .irCustomize:
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private func control(for capability: Capability) -> some View {
        switch capability {
        case .power:
            PowerToggleControl(vm: vm)
        case .press:
            PressControl(vm: vm)
        case .lock:
            LockControl(vm: vm)
        case .vacuum:
            VacuumControl(vm: vm)
        case .colorRGB:
            ColorControl(vm: vm)
        case .irPower, .irCustomize:
            IRCommandControl(vm: vm)
        case .brightness(let range):
            SliderControl(label: "Brightness", symbolName: "sun.max", range: range, value: vm.status?.brightness ?? range.lowerBound) {
                vm.send(.setBrightness($0))
            }
        case .colorTemperature(let range):
            SliderControl(label: "Color Temp", symbolName: "thermometer.sun", range: range, value: vm.status?.colorTemperatureKelvin ?? range.lowerBound) {
                vm.send(.setColorTemperature($0))
            }
        case .position:
            SliderControl(label: "Position", symbolName: "blinds.horizontal.closed", range: 0...100, value: vm.status?.slidePosition ?? 0) {
                vm.send(.setPosition($0))
            }
        case .fanSpeed(let levels):
            SliderControl(label: "Fan Speed", symbolName: "fan", range: 1...levels, value: vm.status?.int(.fanSpeed) ?? 1) {
                vm.send(.setFanSpeed($0))
            }
        case .mode:
            EmptyView()
        case .reading:
            EmptyView() // rendered separately below the primary controls
        }
    }
}
