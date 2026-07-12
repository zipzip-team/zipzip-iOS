//
//  NetworkError.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Foundation

enum NetworkError: Error {
    case invalidURL
    case noResponse
    case decodingError
    case server(statusCode: Int, code: String?, message: String?, body: Data?)
    case unknown(statusCode: Int?)

    var statusCode: Int? {
        switch self {
        case let .server(statusCode, _, _, _):
            statusCode
        case let .unknown(statusCode):
            statusCode
        default:
            nil
        }
    }

    var serverCode: String? {
        guard case let .server(_, code, _, _) = self else { return nil }
        return code
    }

    var isUnauthorized: Bool {
        statusCode == 401
    }
}

extension NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .noResponse:
            return "서버 응답이 없습니다."
        case .decodingError:
            return "데이터 파싱에 실패했습니다."
        case let .server(statusCode, _, message, _):
            return message ?? "요청을 처리하지 못했습니다. (\(statusCode))"
        case let .unknown(code):
            return "알 수 없는 오류가 발생했습니다. (\(code.map(String.init) ?? "no code"))"
        }
    }
}
