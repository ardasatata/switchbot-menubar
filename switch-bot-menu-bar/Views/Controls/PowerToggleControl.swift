//
//  PowerToggleControl.swift
//  switch-bot-menu-bar
//

import SwiftUI

struct PowerToggleControl: View {
    let vm: DeviceViewModel

    var body: some View {
        Toggle(isOn: Binding(
            get: { vm.status?.power == .on },
            set: { vm.send($0 ? .turnOn : .turnOff) }
        )) {
            EmptyView()
        }
        .toggleStyle(.switch)
        .labelsHidden()
        .controlSize(.small)
    }
}
