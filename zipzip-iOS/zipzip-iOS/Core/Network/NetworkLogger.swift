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

    func requestDidResume(_ request: Request) {
        guard let urlRequest = request.request else {
            logger.debug("🛰️ [Request] (no URLRequest)")
            return
        }

        let method = urlRequest.httpMethod ?? "UNKNOWN"
        let url = urlRequest.url?.absoluteString ?? "(no url)"
        let headers = prettyHeaders(urlRequest.headers)
        let body = urlRequest.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "(none)"

        logger.debug(
            """
            🛰️ [Request] \(method, privacy: .public) \(url, privacy: .public)
            Headers: \(headers, privacy: .public)
            Body: \(body, privacy: .public)
            """
        )
    }

    func request(
        _ request: DataRequest,
        didParseResponse response: DataResponse<Data?, AFError>
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
                Body: \(body, privacy: .public)
                """
            )
        } else {
            logger.debug(
                """
                ✅ [Response] \(statusText, privacy: .public) \(method, privacy: .public) \(url, privacy: .public) (\(durationText, privacy: .public))
                Body: \(body, privacy: .public)
                """
            )
        }
    }

    private func prettyHeaders(_ headers: HTTPHeaders) -> String {
        guard !headers.isEmpty else { return "(none)" }
        return headers.map { "\($0.name): \($0.value)" }.joined(separator: ", ")
    }
}
