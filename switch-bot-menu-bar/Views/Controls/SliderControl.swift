//
//  SliderControl.swift
//  switch-bot-menu-bar
//
//  Backs brightness, color-temperature, and position sliders. Debouncing is
//  mandatory here: without it, one drag issues ~100 POSTs and can single-
//  handedly exhaust the 10,000/day rate budget. We only send on release
//  (onEditingChanged) plus a trailing debounce, never on every tick.
//

import SwiftUI

struct SliderControl: View {
    let label: String
    let symbolName: String
    let range: ClosedRange<Double>
    let value: Int
    let onCommit: (Int) -> Void

    @State private var liveValue: Double
    @State private var isEditing = false
    @State private var debounceTask: Task<Void, Never>?

    init(label: String, symbolName: String, range: ClosedRange<Int>, value: Int, onCommit: @escaping (Int) -> Void) {
        self.label = label
        self.symbolName = symbolName
        self.range = Double(range.lowerBound)...Double(range.upperBound)
        self.value = value
        self.onCommit = onCommit
        _liveValue = State(initialValue: Double(value))
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .frame(width: 16)
                .foregroundStyle(.secondary)
            Slider(
                value: $liveValue, in: range,
                onEditingChanged: { editing in
                    isEditing = editing
                    if !editing { commit() }
                }
            )
            Text("\(Int(liveValue))")
                .font(.caption.monospacedDigit())
                .frame(width: 30, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
        .onChange(of: value) { _, newValue in
            guard !isEditing else { return }
            liveValue = Double(newValue)
        }
        .onChange(of: liveValue) { _, _ in
            guard isEditing else { return }
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                commit()
            }
        }
    }

    private func commit() {
        debounceTask?.cancel()
        onCommit(Int(liveValue.rounded()))
    }
}
