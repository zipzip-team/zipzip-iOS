//
//  NetworkProvider.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Foundation
import Alamofire

protocol NetworkProvider {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
}

final class DefaultNetworkProvider: NetworkProvider {
    private let interceptor: RequestInterceptor?
    private let session: Session

    init(
        interceptor: RequestInterceptor? = nil,
        eventMonitors: [EventMonitor] = [NetworkLogger()]
    ) {
        self.interceptor = interceptor
        self.session = Session(eventMonitors: eventMonitors)
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let urlRequest = try endpoint.asURLRequest()

        do {
            return try await session.request(urlRequest, interceptor: interceptor)
                .serializingDecodable(T.self)
                .value
        } catch let afError as AFError {
            throw mapError(afError)
        } catch {
            throw NetworkError.unknown(statusCode: nil)
        }
    }
    
    private func mapError(_ afError: AFError) -> NetworkError {
        if case .responseSerializationFailed = afError {
            return .decodingError
        }
        
        if case .sessionTaskFailed(let error as URLError) = afError,
           error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            return .noResponse
        }
        
        guard let statusCode = afError.responseCode else {
            return .unknown(statusCode: nil)
        }
        
        switch statusCode {
        case 400:
            return .badRequest
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 500...599:
            return .serverError
        default:
            return .unknown(statusCode: statusCode)
        }
    }
}
