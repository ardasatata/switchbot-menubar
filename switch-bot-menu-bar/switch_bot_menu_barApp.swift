//
//  switch_bot_menu_barApp.swift
//  switch-bot-menu-bar
//
//  Created by Arda Satata on 26/02/25.
//

import SwiftUI

@main
struct switch_bot_menu_barApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Owned here, not by MenuContentView: MenuBarExtra(.window) tears down
    // and recreates its content view on every open/close, so a store owned
    // by the view would silently lose all state each time the menu closes.
    @State private var store = AppStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(store)
        } label: {
            StatusBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}
