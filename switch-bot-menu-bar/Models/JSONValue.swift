//
//  JSONValue.swift
//  switch-bot-menu-bar
//
//  A recursive, Sendable, Codable representation of arbitrary JSON.
//
//  SwitchBot's API is not uniformly typed: most `parameter` values are strings
//  ("default", "50", "255:0:0"), but Robot Vacuum's `startClean` takes a nested
//  object, and device status payloads mix numbers, strings, and bools per
//  device type. JSONValue lets both the request and response side model that
//  without per-type Codable structs.
//

import Foundation

enum JSONValue: Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null
}

extension JSONValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Literal conveniences (used when building request bodies in code)

extension JSONValue: ExpressibleByStringLiteral {
    init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) { self = .number(Double(value)) }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

// MARK: - Lenient typed accessors

extension JSONValue {
    /// Coerces "50", 50, and 50.0 alike — SwitchBot is inconsistent about
    /// numeric encoding across device types.
    var asInt: Int? {
        switch self {
        case .number(let value): return Int(value)
        case .string(let value): return Int(value)
        case .bool(let value): return value ? 1 : 0
        default: return nil
        }
    }

    var asDouble: Double? {
        switch self {
        case .number(let value): return value
        case .string(let value): return Double(value)
        default: return nil
        }
    }

    var asString: String? {
        switch self {
        case .string(let value): return value
        case .number(let value):
            return value.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(value)) : String(value)
        case .bool(let value): return value ? "true" : "false"
        default: return nil
        }
    }

    var asBool: Bool? {
        switch self {
        case .bool(let value): return value
        case .string(let value):
            switch value.lowercased() {
            case "true", "on", "1": return true
            case "false", "off", "0": return false
            default: return nil
            }
        case .number(let value): return value != 0
        default: return nil
        }
    }

    var asObject: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var asArray: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }
}

extension Dictionary where Key == String, Value == JSONValue {
    func int(_ key: String) -> Int? { self[key]?.asInt }
    func double(_ key: String) -> Double? { self[key]?.asDouble }
    func string(_ key: String) -> String? { self[key]?.asString }
    func bool(_ key: String) -> Bool? { self[key]?.asBool }
}
