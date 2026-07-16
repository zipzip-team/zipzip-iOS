//
//  NetworkSecretRedactor.swift
//  zipzip-iOS
//

import Foundation

nonisolated enum NetworkSecretRedactor {
    private static let sensitiveKeys: Set<String> = [
        "authorization",
        "authorizationcode",
        "accesstoken",
        "identitytoken",
        "nonce",
        "refreshtoken",
        "uploadurl",
        "originalurl",
        "thumbnailurl",
        "representativeimageurl"
    ]

    static func redactBody(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "(none)" }
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return "(non-json body omitted)"
        }

        let redacted = redact(object)
        guard JSONSerialization.isValidJSONObject(redacted),
              let output = try? JSONSerialization.data(withJSONObject: redacted, options: [.sortedKeys]),
              let string = String(data: output, encoding: .utf8)
        else {
            return "(body omitted)"
        }
        return string
    }

    private static func redact(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, element in
                let key = element.key
                result[key] = sensitiveKeys.contains(key.lowercased()) ? "***" : redact(element.value)
            }
        }
        if let array = value as? [Any] {
            return array.map(redact)
        }
        return value
    }
}
