//
//  NetworkProvider.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Alamofire
import Foundation

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

        let response = await session.request(urlRequest, interceptor: interceptor)
            .validate(statusCode: 200 ..< 300)
            .serializingDecodable(T.self)
            .response

        switch response.result {
        case let .success(value):
            return value
        case let .failure(error):
            throw mapError(error, statusCode: response.response?.statusCode, data: response.data)
        }
    }

    func mapError(_ afError: AFError, statusCode: Int?, data: Data?) -> NetworkError {
        if case let .sessionTaskFailed(error as URLError) = afError {
            let transientCodes: Set<URLError.Code> = [
                .cannotConnectToHost,
                .cannotFindHost,
                .dnsLookupFailed,
                .networkConnectionLost,
                .notConnectedToInternet,
                .timedOut
            ]
            if transientCodes.contains(error.code) {
                return .noResponse
            }
        }

        let statusCode = statusCode ?? afError.responseCode
        if let statusCode,
           200 ..< 300 ~= statusCode,
           case .responseSerializationFailed = afError {
            return .decodingError
        }

        guard let statusCode else {
            if case .responseSerializationFailed = afError {
                return .decodingError
            }
            return .unknown(statusCode: nil)
        }

        let apiError = data.flatMap { try? JSONDecoder().decode(APIErrorResponse.self, from: $0) }
        return .server(
            statusCode: statusCode,
            code: apiError?.code,
            message: apiError?.message,
            body: data
        )
    }
}
