//
//  LockControl.swift
//  switch-bot-menu-bar
//

import SwiftUI

struct LockControl: View {
    let vm: DeviceViewModel

    private var isLocked: Bool { vm.status?.lockState?.lowercased() == "locked" }

    var body: some View {
        Button {
            vm.send(isLocked ? .unlock : .lock)
        } label: {
            Label(isLocked ? "Locked" : "Unlocked", systemImage: isLocked ? "lock.fill" : "lock.open.fill")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .tint(isLocked ? .secondary : .orange)
        .controlSize(.small)
    }
}
