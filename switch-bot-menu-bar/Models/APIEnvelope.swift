//
//  APIEnvelope.swift
//  switch-bot-menu-bar
//
//  Every SwitchBot v1.1 response is wrapped in the same envelope:
//  { "statusCode": Int, "message": String, "body": ... }
//

import Foundation

struct APIEnvelope<Body: Decodable & Sendable>: Decodable, Sendable {
    let statusCode: Int
    let message: String
    let body: Body?

    /// Throws a typed `SwitchBotError` if `statusCode != 100`, otherwise
    /// returns the decoded body (or throws `.decoding` if the body is
    /// unexpectedly absent on a success response).
    func unwrap() throws -> Body {
        guard statusCode == 100 else {
            throw SwitchBotError(statusCode: statusCode, message: message)
        }
        guard let body else {
            throw SwitchBotError.decoding("success response had no body")
        }
        return body
    }
}

/// Some endpoints (e.g. command execution) return a body that we don't need
/// to inspect beyond the envelope's statusCode.
struct EmptyBody: Decodable, Sendable {}
