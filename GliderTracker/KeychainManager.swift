//
//  KeychainManager.swift
//  GliderTracker
//
//  Created by François De Lattre
//  Updated on 04.05.2025
//

import Foundation
import Security

/// A thin wrapper around the iOS Keychain to store a single user identifier (Apple ID).
///
/// The implementation hides the Keychain API details behind three throwing methods
/// using **Swifty** error enums.
@MainActor
final class KeychainManager {

    // MARK: - Singleton
    static let shared = KeychainManager()
    private init() {}

    // MARK: - Public API

    /// Stores the given identifier in the Keychain, replacing any previous value.
    func saveUserIdentifier(_ identifier: String) throws {
        let data = Data(identifier.utf8)

        // Remove an existing value first, ignore the result.
        try? deleteUserIdentifier()

        let query: [String: Any] = [
            kSecClass as String:          kSecClassGenericPassword,
            kSecAttrService as String:    Self.service,
            kSecAttrAccount as String:    Self.account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String:      data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw Error.saveFailed(status) }
    }

    /// Retrieves the identifier from the Keychain or returns `nil` when no value is stored.
    func loadUserIdentifier() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String:          kSecClassGenericPassword,
            kSecAttrService as String:    Self.service,
            kSecAttrAccount as String:    Self.account,
            kSecReturnData as String:     true,
            kSecMatchLimit as String:     kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let identifier = String(data: data, encoding: .utf8)
            else { throw Error.corruptedData }
            return identifier
        case errSecItemNotFound:
            return nil
        default:
            throw Error.loadFailed(status)
        }
    }

    /// Removes the identifier from the Keychain.
    func deleteUserIdentifier() throws {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Error.deleteFailed(status)
        }
    }

    // MARK: - Private

    private static let service = Bundle.main.bundleIdentifier ?? "org.miggu69.GliderTracker"
    private static let account = "com.applesignin.user"

    // MARK: - Error

    enum Error: Swift.Error, LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case corruptedData

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):   "Keychain save failed (\(status))."
            case .loadFailed(let status):   "Keychain load failed (\(status))."
            case .deleteFailed(let status): "Keychain delete failed (\(status))."
            case .corruptedData:            "Keychain data is corrupted."
            }
        }
    }
}
