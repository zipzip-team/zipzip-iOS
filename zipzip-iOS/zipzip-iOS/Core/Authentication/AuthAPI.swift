//
//  AuthAPI.swift
//  zipzip-iOS
//

import Alamofire
import Foundation

protocol AuthAPI: Sendable {
    func loginWithApple(_ request: AppleLoginRequest) async throws -> LoginResponse
    func issueDevelopmentTokens(_ request: DevelopmentTokenRequest) async throws -> LoginResponse
    func deleteDevelopmentUser(testUserKey: String) async throws
    func refresh(refreshToken: String, idempotencyKey: UUID) async throws -> TokenRefreshResponse
    func logout(credential: AuthCredential) async throws
    func withdraw(accessToken: String, tokenType: String) async throws
}

final class DefaultAuthAPI: AuthAPI, @unchecked Sendable {
    private let networkProvider: NetworkProvider

    init(networkProvider: NetworkProvider) {
        self.networkProvider = networkProvider
    }

    func loginWithApple(_ request: AppleLoginRequest) async throws -> LoginResponse {
        let response: APIEnvelope<LoginResponse> = try await networkProvider.request(
            AuthEndpoint.apple(request)
        )
        return response.data
    }

    func issueDevelopmentTokens(_ request: DevelopmentTokenRequest) async throws -> LoginResponse {
        let response: APIEnvelope<LoginResponse> = try await networkProvider.request(
            AuthEndpoint.developmentTokens(request)
        )
        return response.data
    }

    func deleteDevelopmentUser(testUserKey: String) async throws {
        let _: APIVoidEnvelope = try await networkProvider.request(
            AuthEndpoint.deleteDevelopmentUser(testUserKey: testUserKey)
        )
    }

    func refresh(refreshToken: String, idempotencyKey: UUID) async throws -> TokenRefreshResponse {
        let response: APIEnvelope<TokenRefreshResponse> = try await networkProvider.request(
            AuthEndpoint.refresh(refreshToken: refreshToken, idempotencyKey: idempotencyKey)
        )
        return response.data
    }

    func logout(credential: AuthCredential) async throws {
        let _: APIVoidEnvelope = try await networkProvider.request(
            AuthEndpoint.logout(credential)
        )
    }

    func withdraw(accessToken: String, tokenType: String) async throws {
        let _: APIVoidEnvelope = try await networkProvider.request(
            AuthEndpoint.withdraw(accessToken: accessToken, tokenType: tokenType)
        )
    }
}

private enum AuthEndpoint: APIEndpoint {
    case apple(AppleLoginRequest)
    case developmentTokens(DevelopmentTokenRequest)
    case deleteDevelopmentUser(testUserKey: String)
    case refresh(refreshToken: String, idempotencyKey: UUID)
    case logout(AuthCredential)
    case withdraw(accessToken: String, tokenType: String)

    var path: String {
        switch self {
        case .apple:
            "/api/v1/auth/apple"
        case .developmentTokens:
            "/api/v1/dev/auth/tokens"
        case let .deleteDevelopmentUser(testUserKey):
            "/api/v1/dev/auth/users/\(testUserKey)"
        case .refresh:
            "/api/v1/auth/refresh"
        case .logout:
            "/api/v1/auth/logout"
        case .withdraw:
            "/api/v1/users/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .apple, .developmentTokens, .refresh, .logout:
            .post
        case .deleteDevelopmentUser, .withdraw:
            .delete
        }
    }

    var headers: HTTPHeaders? {
        switch self {
        case .apple, .developmentTokens, .deleteDevelopmentUser:
            nil
        case let .refresh(_, idempotencyKey):
            ["Idempotency-Key": idempotencyKey.uuidString]
        case let .logout(credential):
            [.authorization(credential.authorizationHeader)]
        case let .withdraw(accessToken, tokenType):
            [.authorization("\(tokenType) \(accessToken)")]
        }
    }

    var parameters: Parameters? {
        switch self {
        case let .apple(request):
            var parameters: Parameters = [
                "authorizationCode": request.authorizationCode,
                "identityToken": request.identityToken,
                "nonce": request.nonce
            ]
            if let displayName = request.displayName {
                parameters["displayName"] = displayName
            }
            return parameters
        case let .developmentTokens(request):
            return [
                "testUserKey": request.testUserKey,
                "displayName": request.displayName
            ]
        case .deleteDevelopmentUser:
            return nil
        case let .refresh(refreshToken, _):
            return ["refreshToken": refreshToken]
        case let .logout(credential):
            return ["refreshToken": credential.refreshToken]
        case .withdraw:
            return nil
        }
    }

    var encoding: ParameterEncoding {
        JSONEncoding.default
    }
}
