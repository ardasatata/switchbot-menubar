//
//  CredentialStore.swift
//  switch-bot-menu-bar
//

import Foundation
import Security

protocol CredentialStore: Sendable {
    func load() -> SwitchBotCredentials?
    func save(_ credentials: SwitchBotCredentials) throws
    func clear() throws
}

/// In-memory store for unit tests and SwiftUI previews — never touches the
/// real Keychain.
final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: SwitchBotCredentials?

    init(initial: SwitchBotCredentials? = nil) { stored = initial }

    func load() -> SwitchBotCredentials? {
        lock.withLock { stored }
    }

    func save(_ credentials: SwitchBotCredentials) throws {
        lock.withLock { stored = credentials }
    }

    func clear() throws {
        lock.withLock { stored = nil }
    }
}

/// Stores credentials in the Data Protection Keychain, scoped to this app's
/// bundle identifier. Using `kSecUseDataProtectionKeychain` avoids the
/// "wants to use your confidential information" prompt that the file-based
/// login keychain shows whenever the code signature changes between builds,
/// at the (accepted, for a personal app) cost of the item not being visible
/// in Keychain Access.app and being lost if the bundle ID or team changes.
///
/// Reading the Data Protection keychain requires the `keychain-access-groups`
/// entitlement to resolve to a real team prefix. Ad-hoc/unsigned builds (e.g.
/// CI release artifacts, which have no Developer ID cert) have no such
/// prefix, so every operation fails with `errSecMissingEntitlement`
/// (-34018). In that case we fall back to the legacy, file-based login
/// keychain, which works for any signature but re-triggers the confidential-
/// information prompt whenever the binary is rebuilt.
struct KeychainCredentialStore: CredentialStore {
    private let service = "com.ardasatata.switchbot-menubar"
    private let tokenAccount = "openToken"
    private let secretAccount = "secretKey"

    func load() -> SwitchBotCredentials? {
        guard let token = readString(account: tokenAccount),
              let secret = readString(account: secretAccount) else {
            return nil
        }
        return SwitchBotCredentials(token: token, secret: secret)
    }

    func save(_ credentials: SwitchBotCredentials) throws {
        try write(account: tokenAccount, value: credentials.token)
        try write(account: secretAccount, value: credentials.secret)
    }

    func clear() throws {
        delete(account: tokenAccount)
        delete(account: secretAccount)
    }

    // MARK: - SecItem plumbing

    private func baseQuery(account: String, useDataProtection: Bool) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        if useDataProtection {
            query[kSecUseDataProtectionKeychain] = true
        }
        return query
    }

    private func readString(account: String, useDataProtection: Bool = true) -> String? {
        var query = baseQuery(account: account, useDataProtection: useDataProtection)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        if useDataProtection, status == errSecMissingEntitlement {
            return readString(account: account, useDataProtection: false)
        }
        return nil
    }

    private func write(account: String, value: String, useDataProtection: Bool = true) throws {
        let data = Data(value.utf8)
        var query = baseQuery(account: account, useDataProtection: useDataProtection)

        let status: OSStatus
        let updating = readString(account: account, useDataProtection: useDataProtection) != nil
        if updating {
            let attributes: [CFString: Any] = [kSecValueData: data]
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            query[kSecValueData] = data
            query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(query as CFDictionary, nil)
        }

        guard status != errSecSuccess else { return }
        if useDataProtection, status == errSecMissingEntitlement {
            try write(account: account, value: value, useDataProtection: false)
            return
        }
        let verb = updating ? "update" : "save"
        throw SwitchBotError.transport("Keychain \(verb) failed (\(status))")
    }

    private func delete(account: String, useDataProtection: Bool = true) {
        let query = baseQuery(account: account, useDataProtection: useDataProtection)
        let status = SecItemDelete(query as CFDictionary)
        if useDataProtection, status == errSecMissingEntitlement {
            delete(account: account, useDataProtection: false)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
