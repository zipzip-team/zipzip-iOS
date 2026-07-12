//
//  AuthenticatedNetworkProvider.swift
//  zipzip-iOS
//

import Alamofire
import Foundation

final class AuthenticatedNetworkProvider: NetworkProvider {
    private let provider: NetworkProvider
    private let credentialController: SessionCredentialController
    private let onAuthenticationLost: () async -> Void

    init(
        provider: NetworkProvider,
        credentialController: SessionCredentialController,
        onAuthenticationLost: @escaping () async -> Void
    ) {
        self.provider = provider
        self.credentialController = credentialController
        self.onAuthenticationLost = onAuthenticationLost
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        do {
            let credential = try await credentialController.credentialForRequest()

            do {
                return try await provider.request(
                    AuthorizedEndpoint(base: endpoint, credential: credential)
                )
            } catch let error as NetworkError where error.isUnauthorized {
                let replacement = try await credentialController.credentialAfterUnauthorized(credential)
                return try await provider.request(
                    AuthorizedEndpoint(base: endpoint, credential: replacement)
                )
            }
        } catch {
            if await credentialController.current() == nil {
                await onAuthenticationLost()
            }
            throw error
        }
    }
}

private struct AuthorizedEndpoint: APIEndpoint {
    let base: APIEndpoint
    let credential: AuthCredential

    var baseURL: String {
        base.baseURL
    }

    var path: String {
        base.path
    }

    var method: HTTPMethod {
        base.method
    }

    var parameters: Parameters? {
        base.parameters
    }

    var encoding: ParameterEncoding {
        base.encoding
    }

    var headers: HTTPHeaders? {
        var headers = base.headers ?? HTTPHeaders()
        headers.update(.authorization(credential.authorizationHeader))
        return headers
    }
}
