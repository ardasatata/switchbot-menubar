//
//  switch_bot_menu_barUITests.swift
//  switch-bot-menu-barUITests
//
//  Created by Arda Satata on 26/02/25.
//
//  Once LSUIElement = YES, app.windows is empty and app.screenshot()
//  captures nothing — this is now a process-liveness smoke test rather than
//  a window-driven UI test. app.menuBars.statusItems is too flaky across
//  macOS versions to build a real suite on, so the highest-value UI
//  surface (credential entry) isn't exercised here.
//

import XCTest

final class switch_bot_menu_barUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesAndStaysAliveAsAnAgent() throws {
        let app = XCUIApplication()
        app.launch()

        // LSUIElement apps have no window and no Dock icon; the only thing
        // worth asserting from the outside is that the process comes up
        // and doesn't immediately crash.
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if app.state == .runningBackground || app.state == .runningForeground {
                break
            }
        }
        XCTAssertTrue(app.state == .runningBackground || app.state == .runningForeground)
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
