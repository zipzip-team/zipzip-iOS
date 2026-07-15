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

#if DEBUG
    struct DevelopmentAuthConfiguration: Equatable {
        let testUserKey: String
        let displayName: String

        static let current: Self? = {
            guard isEnabled else { return nil }
            return Self(
                testUserKey: requiredValue(for: "DEV_AUTH_TEST_USER_KEY"),
                displayName: requiredValue(for: "DEV_AUTH_DISPLAY_NAME")
            )
        }()

        private static var isEnabled: Bool {
            isEnabled(
                Bundle.main.object(forInfoDictionaryKey: "DEV_AUTH_ENABLED") as? String
            )
        }

        static func isEnabled(_ value: String?) -> Bool {
            guard let value,
                  !value.isEmpty,
                  !value.contains("$(")
            else { return false }

            return switch value.uppercased() {
            case "YES": true
            case "NO": false
            default: preconditionFailure("DEV_AUTH_ENABLED는 YES 또는 NO여야 합니다.")
            }
        }

        private static func requiredValue(for key: String) -> String {
            guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
                  !value.isEmpty,
                  !value.contains("$(")
            else {
                preconditionFailure("\(key) 빌드 설정을 확인해 주세요.")
            }
            return value
        }
    }
#endif
