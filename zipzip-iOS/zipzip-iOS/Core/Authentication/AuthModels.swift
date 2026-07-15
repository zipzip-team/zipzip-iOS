//
//  AuthModels.swift
//  zipzip-iOS
//

import Foundation
import Security

nonisolated struct AuthUser: Codable, Equatable {
    let id: UUID
    let displayName: String
}

nonisolated struct AuthCredential: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresAt: Date

    var requiresRefresh: Bool {
        expiresAt.timeIntervalSinceNow <= 60
    }

    var authorizationHeader: String {
        "\(tokenType) \(accessToken)"
    }
}

nonisolated struct StoredSessionCredential: Codable, Equatable {
    static let schemaVersion = 1

    let version: Int
    let credential: AuthCredential
    let user: AuthUser
    let appleUserIdentifier: String
    let developmentUserKey: String?
    let refreshTokenVersion: Int
    let pendingRefreshIdempotencyKey: UUID?
    let refreshBlockedCode: String?

    init(
        credential: AuthCredential,
        user: AuthUser,
        appleUserIdentifier: String,
        developmentUserKey: String? = nil,
        refreshTokenVersion: Int = 0,
        pendingRefreshIdempotencyKey: UUID? = nil,
        refreshBlockedCode: String? = nil
    ) {
        self.version = Self.schemaVersion
        self.credential = credential
        self.user = user
        self.appleUserIdentifier = appleUserIdentifier
        self.developmentUserKey = developmentUserKey
        self.refreshTokenVersion = refreshTokenVersion
        self.pendingRefreshIdempotencyKey = pendingRefreshIdempotencyKey
        self.refreshBlockedCode = refreshBlockedCode
    }
}

nonisolated struct AppleLoginRequest {
    let identityToken: String
    let authorizationCode: String
    let nonce: String
    let displayName: String?
}

nonisolated struct DevelopmentTokenRequest {
    let testUserKey: String
    let displayName: String
}

nonisolated struct LoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let isNewUser: Bool
    let isRestoredUser: Bool
    let user: AuthUser

    func credential(now: Date = .now) -> AuthCredential {
        AuthCredential(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresAt: now.addingTimeInterval(TimeInterval(expiresIn))
        )
    }
}

nonisolated struct TokenRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int

    func credential(now: Date = .now) -> AuthCredential {
        AuthCredential(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresAt: now.addingTimeInterval(TimeInterval(expiresIn))
        )
    }
}

nonisolated enum AuthSessionError: Error, Equatable {
    case missingCredential
    case invalidTokenType
    case staleOperation
    case refreshBlocked(String)
    case keychain(OSStatus)
    case invalidKeychainData
}

extension AuthSessionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingCredential:
            "로그인이 필요합니다."
        case .invalidTokenType:
            "지원하지 않는 인증 방식입니다."
        case .staleOperation:
            "이미 종료된 인증 요청입니다."
        case .refreshBlocked:
            "로그인 정보를 갱신할 수 없습니다. 다시 로그인해 주세요."
        case let .keychain(status):
            "로그인 정보를 안전하게 저장하지 못했습니다. (\(status))"
        case .invalidKeychainData:
            "저장된 로그인 정보를 읽지 못했습니다."
        }
    }
}
