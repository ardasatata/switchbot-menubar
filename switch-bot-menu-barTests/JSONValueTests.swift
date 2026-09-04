//
//  JSONValueTests.swift
//  switch-bot-menu-barTests
//

import Foundation
import Testing
@testable import switch_bot_menu_bar

struct JSONValueTests {

    @Test func decodesAllPrimitiveKinds() throws {
        let json = """
        {"s": "hello", "n": 42, "d": 1.5, "b": true, "nil": null, "a": [1, "two"], "o": {"x": 1}}
        """
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: Data(json.utf8))
        #expect(decoded["s"] == .string("hello"))
        #expect(decoded["n"] == .number(42))
        #expect(decoded["d"] == .number(1.5))
        #expect(decoded["b"] == .bool(true))
        #expect(decoded["nil"] == .null)
        #expect(decoded["a"] == .array([.number(1), .string("two")]))
        #expect(decoded["o"] == .object(["x": .number(1)]))
    }

    @Test func roundTripsThroughEncodeDecode() throws {
        let original = JSONValue.object([
            "action": .string("sweep"),
            "param": .object(["fanLevel": .number(1), "waterLevel": .number(1), "times": .number(1)]),
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == original)
    }

    /// The Robot Vacuum `startClean` parameter is a nested object rather
    /// than the plain-string parameter every other command uses — this is
    /// exactly why DeviceCommand.parameter is JSONValue, not String.
    @Test func supportsNestedObjectParameter() throws {
        let command = DeviceCommand(
            command: "startClean",
            parameter: .object(["action": "sweep", "param": .object(["fanLevel": 1])]),
            commandType: "command"
        )
        let data = try JSONEncoder().encode(command)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"action\":\"sweep\""))
    }

    @Test(arguments: [
        (JSONValue.string("50"), 50),
        (JSONValue.number(50), 50),
        (JSONValue.number(50.9), 50),
        (JSONValue.bool(true), 1),
    ])
    func lenientIntCoercion(value: JSONValue, expected: Int) {
        #expect(value.asInt == expected)
    }

    @Test func lenientStringCoercionOfWholeNumberDouble() {
        #expect(JSONValue.number(50).asString == "50")
    }
}
