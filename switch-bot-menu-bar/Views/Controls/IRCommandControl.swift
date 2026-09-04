//
//  IRCommandControl.swift
//  switch-bot-menu-bar
//
//  Infrared remotes (Air Conditioner, TV, etc.) have no status endpoint —
//  SwitchBot can't tell us whether the physical appliance is on. Controls
//  are fire-and-forget commands rather than a bound toggle.
//

import SwiftUI

struct IRCommandControl: View {
    let vm: DeviceViewModel

    var body: some View {
        HStack(spacing: 6) {
            Button {
                vm.send(.turnOn)
            } label: {
                Image(systemName: "power")
            }
            Button {
                vm.send(.turnOff)
            } label: {
                Image(systemName: "power.circle")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
