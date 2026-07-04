//
//  NetworkLogger.swift
//  zipzip-iOS
//
//  Created by 성환 on 6/29/26.
//

import Foundation
import OSLog
import Alamofire

final class NetworkLogger: EventMonitor {
    let queue = DispatchQueue(label: "com.zipzip.network.logger", qos: .utility)

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zipzip-iOS",
        category: "Network"
    )

    func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        let method = urlRequest.httpMethod ?? "UNKNOWN"
        let url = urlRequest.url?.absoluteString ?? "(no url)"
        let headers = prettyHeaders(urlRequest.headers)
        let body = urlRequest.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "(none)"

        logger.debug(
            """
            🛰️ [Request] \(method, privacy: .public) \(url, privacy: .public)
            Headers: \(headers)
            Body: \(body)
            """
        )
    }

    func request<Value>(
        _ request: DataRequest,
        didParseResponse response: DataResponse<Value, AFError>
    ) {
        let method = request.request?.httpMethod ?? "UNKNOWN"
        let url = request.request?.url?.absoluteString ?? "(no url)"
        let statusCode = response.response?.statusCode
        let duration = response.metrics.map { $0.taskInterval.duration * 1000 } ?? 0
        let durationText = String(format: "%.0fms", duration)
        let statusText = statusCode.map(String.init) ?? "-"
        let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "(none)"

        if let error = response.error {
            logger.error(
                """
                ❌ [Response] \(statusText, privacy: .public) \(method, privacy: .public) \(url, privacy: .public) (\(durationText, privacy: .public))
                Error: \(error.localizedDescription, privacy: .public)
                Body: \(body)
                """
            )
        } else {
            logger.debug(
                """
                ✅ [Response] \(statusText, privacy: .public) \(method, privacy: .public) \(url, privacy: .public) (\(durationText, privacy: .public))
                Body: \(body)
                """
            )
        }
    }

    /// 인증 토큰 등 민감 헤더는 값을 가려 로그에 남기지 않는다.
    private static let sensitiveHeaders: Set<String> = [
        "authorization", "cookie", "set-cookie", "proxy-authorization"
    ]

    private func prettyHeaders(_ headers: HTTPHeaders) -> String {
        guard !headers.isEmpty else { return "(none)" }
        return headers.map { header in
            let value = Self.sensitiveHeaders.contains(header.name.lowercased()) ? "***" : header.value
            return "\(header.name): \(value)"
        }.joined(separator: ", ")
    }
}
