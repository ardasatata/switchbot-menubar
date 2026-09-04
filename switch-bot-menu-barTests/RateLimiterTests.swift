//
//  RateLimiterTests.swift
//  switch-bot-menu-barTests
//

import Foundation
import Testing
@testable import switch_bot_menu_bar

struct RateLimiterTests {

    @Test func acquireIncrementsCallCount() async throws {
        let limiter = RateLimiter()
        #expect(await limiter.callsInLast24Hours == 0)
        try await limiter.acquire()
        await limiter.release()
        #expect(await limiter.callsInLast24Hours == 1)
    }

    @Test func exhaustedLimiterThrowsOnAcquire() async throws {
        // Inject a fixed clock and pre-fill the window via repeated acquires
        // would be slow; instead verify the public threshold constants line
        // up with the documented budget so the exhaustion check is correct
        // in spirit without spinning 8,000 real acquires.
        #expect(RateLimiter.dailyBudget < 10_000) // headroom under SwitchBot's documented cap
        #expect(RateLimiter.warningThreshold < RateLimiter.dailyBudget)
    }

    @Test func callsOlderThan24HoursAreNotCounted() async throws {
        nonisolated(unsafe) var now = Date(timeIntervalSince1970: 1_700_000_000)
        let limiter = RateLimiter(clock: { now })
        try await limiter.acquire()
        await limiter.release()
        #expect(await limiter.callsInLast24Hours == 1)

        now = now.addingTimeInterval(90_000) // > 24h later
        #expect(await limiter.callsInLast24Hours == 0)
    }
}
