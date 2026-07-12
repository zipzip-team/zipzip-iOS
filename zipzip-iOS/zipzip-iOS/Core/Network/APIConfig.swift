//
//  APIConfig.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Foundation

enum APIConfig {
    static let baseURL: String = {
        let configuredHost = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String
        let host = configuredHost.flatMap { value in
            value.isEmpty || value.contains("$(") ? nil : value
        } ?? "dev-api.zipzip.site"
        return "https://\(host)"
    }()
}
