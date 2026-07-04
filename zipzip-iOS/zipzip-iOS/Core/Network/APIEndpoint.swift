//
//  APIEndpoint.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Alamofire
import Foundation

protocol APIEndpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: HTTPHeaders? { get }
    var parameters: Parameters? { get }
    var encoding: ParameterEncoding { get }
}

extension APIEndpoint {
    var baseURL: String {
        APIConfig.baseURL
    }

    func asURLRequest() throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.method = method
        request.headers = headers ?? HTTPHeaders()

        return try encoding.encode(request, with: parameters)
    }
}
