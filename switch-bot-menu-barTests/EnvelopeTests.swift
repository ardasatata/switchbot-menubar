//
//  EnvelopeTests.swift
//  switch-bot-menu-barTests
//

import Foundation
import Testing
@testable import switch_bot_menu_bar

struct EnvelopeTests {

    @Test func statusCode100UnwrapsBody() throws {
        let envelope = APIEnvelope<EmptyBody>(statusCode: 100, message: "success", body: EmptyBody())
        #expect(throws: Never.self) { try envelope.unwrap() }
    }

    @Test func successWithMissingBodyThrowsDecodingError() {
        let envelope = APIEnvelope<EmptyBody>(statusCode: 100, message: "success", body: nil)
        #expect(throws: SwitchBotError.self) { try envelope.unwrap() }
    }

    @Test(arguments: [
        (401, SwitchBotError.unauthorized),
        (151, SwitchBotError.deviceTypeError),
        (152, SwitchBotError.deviceNotFound),
        (160, SwitchBotError.commandUnsupported),
        (161, SwitchBotError.deviceOffline),
        (171, SwitchBotError.hubOffline),
        (190, SwitchBotError.systemError),
    ])
    func statusCodeMapsToTypedError(code: Int, expected: SwitchBotError) {
        let envelope = APIEnvelope<EmptyBody>(statusCode: code, message: "x", body: nil)
        #expect(throws: expected) { try envelope.unwrap() }
    }

    @Test func unknownStatusCodeMapsToGenericAPIError() {
        let envelope = APIEnvelope<EmptyBody>(statusCode: 999, message: "weird", body: nil)
        #expect(throws: SwitchBotError.api(code: 999, message: "weird")) { try envelope.unwrap() }
    }
}
