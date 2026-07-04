//
//  APIConfig.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Foundation

enum APIConfig {
    static let baseURL: String = {
        guard
            let host = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String,
            !host.isEmpty
        else {
            fatalError("BASE_URL이 설정되지 않았습니다. Config.xcconfig를 확인하세요.")
        }
        return "https://\(host)"
    }()
}
