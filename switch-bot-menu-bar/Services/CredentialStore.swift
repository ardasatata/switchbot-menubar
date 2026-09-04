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

    private func baseQuery(account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true,
        ]
    }

    private func readString(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(account: String, value: String) throws {
        let data = Data(value.utf8)
        var query = baseQuery(account: account)

        if readString(account: account) != nil {
            let attributes: [CFString: Any] = [kSecValueData: data]
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                throw SwitchBotError.transport("Keychain update failed (\(status))")
            }
        } else {
            query[kSecValueData] = data
            query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw SwitchBotError.transport("Keychain save failed (\(status))")
            }
        }
    }

    private func delete(account: String) {
        let query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
