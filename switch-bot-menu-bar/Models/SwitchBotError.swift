//
//  SwitchBotError.swift
//  switch-bot-menu-bar
//

import Foundation

/// Typed mapping of SwitchBot's `statusCode` values plus local failure modes.
/// See: https://github.com/OpenWonderLabs/SwitchBotAPI
enum SwitchBotError: Error, Equatable, Sendable {
    case unauthorized              // 401 — bad token/secret or signature
    case deviceTypeError           // 151
    case deviceNotFound            // 152
    case commandUnsupported        // 160
    case deviceOffline             // 161
    case hubOffline                // 171
    case systemError               // 190
    case api(code: Int, message: String)   // any other non-100 statusCode
    case rateLimitExhausted
    case transport(String)
    case decoding(String)
    case missingCredentials

    init(statusCode: Int, message: String) {
        switch statusCode {
        case 401: self = .unauthorized
        case 151: self = .deviceTypeError
        case 152: self = .deviceNotFound
        case 160: self = .commandUnsupported
        case 161: self = .deviceOffline
        case 171: self = .hubOffline
        case 190: self = .systemError
        default: self = .api(code: statusCode, message: message)
        }
    }

    var isRetryable: Bool {
        switch self {
        case .deviceOffline, .hubOffline, .transport, .systemError:
            return true
        default:
            return false
        }
    }
}

extension SwitchBotError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Invalid token or secret key. Please check your credentials in Settings."
        case .deviceTypeError:
            return "This device type doesn't support that action."
        case .deviceNotFound:
            return "Device not found. It may have been removed from your account."
        case .commandUnsupported:
            return "This device doesn't support that command."
        case .deviceOffline:
            return "Device is offline."
        case .hubOffline:
            return "The hub for this device is offline."
        case .systemError:
            return "SwitchBot's servers reported a system error. Try again shortly."
        case .api(let code, let message):
            return "SwitchBot API error \(code): \(message)"
        case .rateLimitExhausted:
            return "Daily API call limit reached. Automatic refresh is paused until tomorrow."
        case .transport(let message):
            return "Network error: \(message)"
        case .decoding(let message):
            return "Couldn't understand SwitchBot's response: \(message)"
        case .missingCredentials:
            return "No SwitchBot credentials are configured yet."
        }
    }
}
