//
//  URLSessionHTTPClientTests.swift
//  switch-bot-menu-barTests
//
//  The one integration test proving the real URLSession-backed HTTPClient
//  wiring (headers, body, status handling). Everything else is covered
//  against StubHTTPClient, which carries the majority of coverage with no
//  network involved. Uses an NSLock-backed handler box rather than
//  Synchronization.Mutex: that type needs macOS 15, one above this app's
//  14.0 deployment target.
//

import Foundation
import Testing
@testable import switch_bot_menu_bar

final class StubURLProtocolBox: @unchecked Sendable {
    static let shared = StubURLProtocolBox()
    private let lock = NSLock()
    private var _handler: (@Sendable (URLRequest) -> (Data, HTTPURLResponse))?

    var handler: (@Sendable (URLRequest) -> (Data, HTTPURLResponse))? {
        get { lock.withLock { _handler } }
        set { lock.withLock { _handler = newValue } }
    }
}

final class StubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubURLProtocolBox.shared.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (data, response) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

// Swift Testing runs tests in a struct concurrently by default; both tests
// here install a handler into the process-wide StubURLProtocolBox, so they
// must not interleave or one test's handler can answer the other's request.
@Suite(.serialized)
struct URLSessionHTTPClientTests {

    @Test func sendsHeadersAndBodyAndDecodesSuccessResponse() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let client = URLSessionHTTPClient(session: URLSession(configuration: config))

        nonisolated(unsafe) var capturedRequest: URLRequest?
        StubURLProtocolBox.shared.handler = { request in
            capturedRequest = request
            let json = Data(#"{"statusCode":100,"message":"success","body":{"deviceList":[],"infraredRemoteList":[]}}"#.utf8)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }
        defer { StubURLProtocolBox.shared.handler = nil }

        let switchBotClient = SwitchBotClient(
            httpClient: client,
            credentials: SwitchBotCredentials(token: "tok", secret: "sec"),
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            nonce: { "fixed-nonce" }
        )

        _ = try await switchBotClient.devices()

        let request = try #require(capturedRequest)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "tok")
        #expect(request.value(forHTTPHeaderField: "nonce") == "fixed-nonce")
        #expect(request.value(forHTTPHeaderField: "t") == "1700000000000")
        #expect(request.value(forHTTPHeaderField: "sign")?.isEmpty == false)
        #expect(request.url?.path == "/v1.1/devices")
    }

    @Test func nonSuccessHTTPStatusThrowsTransportError() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let client = URLSessionHTTPClient(session: URLSession(configuration: config))

        StubURLProtocolBox.shared.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }
        defer { StubURLProtocolBox.shared.handler = nil }

        let switchBotClient = SwitchBotClient(httpClient: client, credentials: SwitchBotCredentials(token: "tok", secret: "sec"))

        await #expect(throws: SwitchBotError.self) {
            _ = try await switchBotClient.devices()
        }
    }
}
