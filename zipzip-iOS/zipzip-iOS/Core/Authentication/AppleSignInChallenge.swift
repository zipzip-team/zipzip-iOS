//
//  AppleSignInChallenge.swift
//  zipzip-iOS
//

import Foundation
import Security

nonisolated struct AppleSignInChallenge: Equatable {
    let nonce: String
    let state: String

    static func make() throws -> AppleSignInChallenge {
        AppleSignInChallenge(
            nonce: try secureRandomString(byteCount: 32),
            state: try secureRandomString(byteCount: 32)
        )
    }

    private static func secureRandomString(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        guard status == errSecSuccess else {
            throw AuthSessionError.keychain(status)
        }
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
