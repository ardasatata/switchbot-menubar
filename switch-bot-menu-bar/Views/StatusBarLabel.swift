//
//  StatusBarLabel.swift
//  switch-bot-menu-bar
//

import SwiftUI

struct StatusBarLabel: View {
    let store: AppStore

    var body: some View {
        Image(systemName: symbolName)
    }

    private var symbolName: String {
        if store.lastError != nil { return "exclamationmark.triangle" }
        if store.authState == .needsOnboarding { return "bolt.horizontal.circle" }
        return "bolt.horizontal.circle.fill"
    }
}
