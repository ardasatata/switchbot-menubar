//
//  VacuumControl.swift
//  switch-bot-menu-bar
//

import SwiftUI

struct VacuumControl: View {
    let vm: DeviceViewModel

    var body: some View {
        HStack(spacing: 6) {
            Button {
                vm.send(.vacuumStart)
            } label: {
                Image(systemName: "play.fill")
            }
            Button {
                vm.send(.vacuumStop)
            } label: {
                Image(systemName: "stop.fill")
            }
            Button {
                vm.send(.vacuumDock)
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
