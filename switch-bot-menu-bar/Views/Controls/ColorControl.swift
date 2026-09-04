//
//  ColorControl.swift
//  switch-bot-menu-bar
//

import SwiftUI

struct ColorControl: View {
    let vm: DeviceViewModel

    var body: some View {
        let binding: Binding<Color> = Binding(
            get: { currentColor },
            set: { newColor in
                let (r, g, b) = components(of: newColor)
                vm.send(.setColorRGB(r: r, g: g, b: b))
            }
        )
        ColorPicker(selection: binding, supportsOpacity: false) {
            EmptyView()
        }
        .labelsHidden()
    }

    private var currentColor: Color {
        guard let rgb = vm.status?.colorRGB else { return .white }
        return Color(
            red: Double(rgb.r) / 255,
            green: Double(rgb.g) / 255,
            blue: Double(rgb.b) / 255
        )
    }

    private func components(of color: Color) -> (Int, Int, Int) {
        let resolved = color.resolve(in: .init())
        return (
            Int((resolved.red * 255).rounded()),
            Int((resolved.green * 255).rounded()),
            Int((resolved.blue * 255).rounded())
        )
    }
}
