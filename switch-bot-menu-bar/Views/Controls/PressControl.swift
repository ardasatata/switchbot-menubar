//
//  PressControl.swift
//  switch-bot-menu-bar
//
//  Bot in "press" deviceMode has no persistent power state — pressing is a
//  momentary action (e.g. a physical button push), so this is a plain
//  button rather than a toggle.
//

import SwiftUI

struct PressControl: View {
    let vm: DeviceViewModel

    var body: some View {
        Button {
            vm.send(.press)
        } label: {
            Image(systemName: "hand.tap.fill")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
