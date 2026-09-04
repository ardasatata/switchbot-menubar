//
//  StubHTTPClient.swift
//  switch-bot-menu-barTests
//
//  A spy/stub HTTPClient: request bodies are directly inspectable and there
//  is zero network flakiness, so this carries the majority of SwitchBotClient
//  and AppStore test coverage. See URLSessionHTTPClientTests for the one
//  integration test that proves the real URLSession-backed wiring.
//

import Foundation
@testable import switch_bot_menu_bar

actor StubHTTPClient: HTTPClient {
    struct Recorded: Sendable {
        let request: URLRequest
        let path: String
    }

    private(set) var recordedRequests: [Recorded] = []
    /// Keyed by path (e.g. "/v1.1/devices"); consumed in FIFO order per key
    /// so a test can queue multiple responses for repeated calls.
    private var responsesByPath: [String: [(Data, Int)]] = [:]
    private var defaultResponse: (Data, Int)?

    func queue(path: String, json: String, statusCode: Int = 200) {
        responsesByPath[path, default: []].append((Data(json.utf8), statusCode))
    }

    func setDefault(json: String, statusCode: Int = 200) {
        defaultResponse = (Data(json.utf8), statusCode)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let path = request.url?.path ?? ""
        recordedRequests.append(Recorded(request: request, path: path))

        let response: (Data, Int)
        if var queued = responsesByPath[path], !queued.isEmpty {
            response = queued.removeFirst()
            responsesByPath[path] = queued
        } else if let defaultResponse {
            response = defaultResponse
        } else {
            response = (Data("""
            {"statusCode": 190, "message": "no stub configured for \(path)", "body": {}}
            """.utf8), 200)
        }

        let httpResponse = HTTPURLResponse(url: request.url!, statusCode: response.1, httpVersion: nil, headerFields: nil)!
        return (response.0, httpResponse)
    }

    var callCount: Int {
        get async { recordedRequests.count }
    }

    func callCount(forPath path: String) -> Int {
        recordedRequests.filter { $0.path == path }.count
    }

    func lastBody(forPath path: String) -> [String: Any]? {
        guard let request = recordedRequests.last(where: { $0.path == path })?.request,
              let body = request.httpBody else { return nil }
        return try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }
}
