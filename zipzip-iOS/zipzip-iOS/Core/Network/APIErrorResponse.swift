//
//  APIErrorResponse.swift
//  zipzip-iOS
//

import Foundation

nonisolated struct APIErrorResponse: Decodable {
    let status: Int?
    let code: String?
    let message: String?
}

nonisolated struct APIEnvelope<Value: Decodable & Sendable>: Decodable {
    let status: Int?
    let code: String?
    let message: String?
    let data: Value
}

nonisolated struct EmptyResponse: Decodable {}

nonisolated struct APIVoidEnvelope: Decodable {
    let status: Int?
    let code: String?
    let message: String?
}
