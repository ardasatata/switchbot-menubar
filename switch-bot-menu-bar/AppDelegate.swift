//
//  AppDelegate.swift
//  switch-bot-menu-bar
//
//  With LSUIElement = NO the app has a Dock icon, but its only real UI is
//  the MenuBarExtra popover and the Settings window — there's no main
//  window to reveal on a Dock-icon click. This makes that click useful
//  (open Settings) instead of appearing to do nothing.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }
}
