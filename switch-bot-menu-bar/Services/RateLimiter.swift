//
//  RateLimiter.swift
//  switch-bot-menu-bar
//
//  Guards against exceeding SwitchBot's 10,000 calls/day budget. Uses a
//  rolling 24h window (not "midnight reset") since the API doesn't document
//  a reset time and the token's quota may be shared with the official app.
//

import Foundation

actor RateLimiter {
    /// Headroom under the documented 10,000/day cap — the SwitchBot mobile
    /// app shares the same token's quota.
    static let dailyBudget = 8_000
    static let warningThreshold = 6_000
    static let minSpacing: Duration = .milliseconds(100)
    static let maxConcurrent = 3

    private var timestamps: [Date] = []
    private var inFlight = 0
    private var lastRequestAt: Date?
    private let clock: @Sendable () -> Date

    init(clock: @escaping @Sendable () -> Date = { Date() }) {
        self.clock = clock
    }

    enum LimiterError: Error, Sendable {
        case exhausted
    }

    var callsInLast24Hours: Int {
        prune()
        return timestamps.count
    }

    var isExhausted: Bool { callsInLast24Hours >= Self.dailyBudget }
    var isNearLimit: Bool { callsInLast24Hours >= Self.warningThreshold }

    /// Call immediately before issuing a network request. Throws
    /// `.exhausted` if the daily budget is spent; otherwise waits out
    /// minimum spacing / concurrency limits, then records the call.
    func acquire() async throws {
        guard !isExhausted else { throw LimiterError.exhausted }

        while inFlight >= Self.maxConcurrent {
            try await Task.sleep(for: .milliseconds(20))
        }

        if let lastRequestAt {
            let elapsed = clock().timeIntervalSince(lastRequestAt)
            let minSeconds = Double(Self.minSpacing.components.seconds)
                + Double(Self.minSpacing.components.attoseconds) / 1e18
            if elapsed < minSeconds {
                try await Task.sleep(for: .seconds(minSeconds - elapsed))
            }
        }

        inFlight += 1
        lastRequestAt = clock()
        timestamps.append(clock())
    }

    func release() {
        inFlight = max(0, inFlight - 1)
    }

    private func prune() {
        let cutoff = clock().addingTimeInterval(-86_400)
        timestamps.removeAll { $0 < cutoff }
    }
}
