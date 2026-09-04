//
//  HTTPClient.swift
//  switch-bot-menu-bar
//
//  Thin seam over networking so SwitchBotClient can be tested with a spy
//  or fixture-backed stub instead of hitting the real network.
//

import Foundation

protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionHTTPClient: HTTPClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw SwitchBotError.transport("non-HTTP response")
            }
            return (data, http)
        } catch let error as SwitchBotError {
            throw error
        } catch {
            throw SwitchBotError.transport(error.localizedDescription)
        }
    }
}
