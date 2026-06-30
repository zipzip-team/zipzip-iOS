//
//  NetworkError.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Foundation

enum NetworkError: Error {
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case invalidURL
    case serverError
    case noResponse
    case decodingError
    case unknown(statusCode: Int?)
}

extension NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .badRequest:
            return "잘못된 요청입니다."
        case .unauthorized:
            return "인증에 실패했습니다."
        case .forbidden:
            return "접근 권한이 없습니다."
        case .notFound:
            return "요청한 리소스를 찾을 수 없습니다."
        case .invalidURL:
            return "잘못된 URL입니다."
        case .serverError:
            return "서버에서 오류가 발생했습니다."
        case .noResponse:
            return "서버 응답이 없습니다."
        case .decodingError:
            return "데이터 파싱에 실패했습니다."
        case .unknown(let code):
            return "알 수 없는 오류가 발생했습니다. (\(code.map(String.init) ?? "no code"))"
        }
    }
}
