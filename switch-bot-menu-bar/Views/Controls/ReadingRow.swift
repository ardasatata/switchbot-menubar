//
//  ReadingRow.swift
//  switch-bot-menu-bar
//
//  Read-only sensor line, driven entirely by ReadingSpec — no per-device
//  code here either.
//

import SwiftUI

struct ReadingRow: View {
    let vm: DeviceViewModel
    let key: StatusKey

    var body: some View {
        if let spec = ReadingSpec.spec(for: key), let value = vm.reading(key) {
            Label {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: spec.symbolName)
                    .foregroundStyle(.secondary)
            }
            .labelStyle(.titleAndIcon)
        }
    }
}
