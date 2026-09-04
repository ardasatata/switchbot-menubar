//
//  RequestSigner.swift
//  switch-bot-menu-bar
//
//  Pure signing logic for the SwitchBot v1.1 API — no clock, no UUID
//  generation, so it is fully deterministic and unit-testable.
//
//  sign = Base64(HMAC-SHA256(key: secret, message: token + t + nonce)).uppercased()
//

import Foundation
import CryptoKit

enum RequestSigner {
    /// - Parameters:
    ///   - token: the SwitchBot Open Token.
    ///   - secret: the SwitchBot Secret Key.
    ///   - timestampMillis: 13-digit millisecond epoch timestamp, as a string.
    ///   - nonce: a request-unique nonce (a UUID string is fine).
    static func sign(token: String, secret: String, timestampMillis: String, nonce: String) -> String {
        let message = token + timestampMillis + nonce
        let key = SymmetricKey(data: Data(secret.utf8))
        let authenticationCode = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        return Data(authenticationCode).base64EncodedString().uppercased()
    }

    /// SwitchBot expects a 13-digit millisecond epoch timestamp.
    static func timestampMillis(now: Date) -> String {
        String(Int64((now.timeIntervalSince1970 * 1000).rounded()))
    }
}
