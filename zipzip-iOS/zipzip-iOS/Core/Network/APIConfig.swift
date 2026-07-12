//
//  APIConfig.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Foundation

enum APIConfig {
    static let baseURL: String = {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String,
              !host.isEmpty,
              !host.contains("$(")
        else {
            preconditionFailure("BASE_URL 빌드 설정을 확인해 주세요.")
        }
        return "https://\(host)"
    }()
}
