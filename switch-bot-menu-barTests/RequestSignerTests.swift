//
//  RequestSignerTests.swift
//  switch-bot-menu-barTests
//
//  RequestSigner is a pure function — no clock, no UUID — so its output is
//  fully deterministic and verifiable against known HMAC-SHA256 vectors.
//

import Foundation
import Testing
@testable import switch_bot_menu_bar

struct RequestSignerTests {

    /// RFC 4231 Test Case 2 (key="Jefe", data="what do ya want for nothing?").
    /// Since sign()'s message is token + timestampMillis + nonce, putting the
    /// RFC's data entirely in `token` and leaving timestamp/nonce empty
    /// reproduces the RFC vector exactly, proving the HMAC + Base64 pipeline
    /// is correct independent of SwitchBot's specific field concatenation.
    @Test func matchesRFC4231TestVector() {
        let signature = RequestSigner.sign(
            token: "what do ya want for nothing?",
            secret: "Jefe",
            timestampMillis: "",
            nonce: ""
        )
        #expect(signature == "W9ZBRR9GDU5QBCQMCJV1X1OAPWIDJZMDNEXYUWTSOEM=")
    }

    @Test func signatureIsUppercased() {
        let signature = RequestSigner.sign(token: "tok", secret: "sec", timestampMillis: "123", nonce: "abc")
        #expect(signature == signature.uppercased())
    }

    @Test func signatureIsDeterministicForSameInputs() {
        let a = RequestSigner.sign(token: "tok", secret: "sec", timestampMillis: "123", nonce: "abc")
        let b = RequestSigner.sign(token: "tok", secret: "sec", timestampMillis: "123", nonce: "abc")
        #expect(a == b)
    }

    @Test func differentNonceProducesDifferentSignature() {
        let a = RequestSigner.sign(token: "tok", secret: "sec", timestampMillis: "123", nonce: "abc")
        let b = RequestSigner.sign(token: "tok", secret: "sec", timestampMillis: "123", nonce: "xyz")
        #expect(a != b)
    }

    @Test func timestampIsThirteenDigits() {
        let timestamp = RequestSigner.timestampMillis(now: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(timestamp.count == 13)
        #expect(Int64(timestamp) != nil)
    }
}
