//
//  CredentialStore.swift
//  zipzip-iOS
//

import Foundation
import Security

protocol CredentialStore: Sendable {
    func load() async throws -> StoredSessionCredential?
    func save(_ credential: StoredSessionCredential) async throws
    func delete() async throws
    func delete(ifMatching credential: StoredSessionCredential) async throws
}

actor KeychainCredentialStore: CredentialStore {
    private let service: String
    private let account = "zipzip-session"

    init(service: String = "app.zipzip.ios.authentication") {
        self.service = service
    }

    func load() throws -> StoredSessionCredential? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw AuthSessionError.keychain(status)
        }
        guard let data = item as? Data,
              let credential = try? JSONDecoder().decode(StoredSessionCredential.self, from: data),
              credential.version == StoredSessionCredential.schemaVersion
        else {
            throw AuthSessionError.invalidKeychainData
        }
        return credential
    }

    func save(_ credential: StoredSessionCredential) throws {
        let data = try JSONEncoder().encode(credential)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw AuthSessionError.keychain(addStatus)
            }
            return
        }

        guard updateStatus == errSecSuccess else {
            throw AuthSessionError.keychain(updateStatus)
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthSessionError.keychain(status)
        }
    }

    func delete(ifMatching credential: StoredSessionCredential) throws {
        guard try load() == credential else { return }
        try delete()
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
    }
}
