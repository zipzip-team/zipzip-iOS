//
//  PlaceLabelCatalog.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import Foundation

enum PlaceLabelCatalog {
    nonisolated static func label(
        regionCode: String?,
        regionName: String?,
        fullAddress: String?
    ) -> String? {
        if let regionCode, regionCode.uppercased() != "KR" {
            return regionName?.trimmed
        }
        return koreanLabel(from: fullAddress) ?? regionName?.trimmed
    }

    private nonisolated static func koreanLabel(from fullAddress: String?) -> String? {
        guard let fullAddress, !fullAddress.isEmpty else { return nil }

        let tokens = fullAddress
            .components(separatedBy: CharacterSet(charactersIn: " \t\n,"))
            .map(\.trimmed)
            .filter { !$0.isEmpty && $0 != "대한민국" }

        var metro: String?
        var province: String?
        var si: String?
        var gu: String?
        var gun: String?
        var dong: String?
        var eupMyeonRi: String?

        for token in tokens {
            if ["특별시", "광역시", "특별자치시"].contains(where: token.hasSuffix) {
                metro = metro ?? token
            } else if token.hasSuffix("도") {
                province = province ?? token
            } else if token.hasSuffix("시") {
                si = si ?? token
            } else if token.hasSuffix("구") {
                if let siRange = token.range(of: "시"), siRange.upperBound < token.endIndex {
                    si = si ?? String(token[..<siRange.upperBound])
                    gu = gu ?? String(token[siRange.upperBound...])
                } else {
                    gu = gu ?? token
                }
            } else if token.hasSuffix("군") {
                gun = gun ?? token
            } else if token.hasSuffix("동") {
                dong = dong ?? token
            } else if ["읍", "면", "리"].contains(where: token.hasSuffix) {
                eupMyeonRi = eupMyeonRi ?? token
            }
        }

        let siLabel = si ?? metro.map(abbreviatedMetro) ?? province

        let parts: [String?]
        if gu != nil {
            parts = [siLabel, gu]
        } else if dong != nil {
            parts = [siLabel, dong]
        } else if eupMyeonRi != nil {
            parts = [gun ?? siLabel, eupMyeonRi]
        } else {
            parts = [gun ?? siLabel]
        }

        let label = parts.compactMap { $0 }.joined(separator: " ").trimmed
        return label.isEmpty ? nil : label
    }

    private nonisolated static func abbreviatedMetro(_ metro: String) -> String {
        for suffix in ["특별자치시", "특별시", "광역시"] where metro.hasSuffix(suffix) {
            return String(metro.dropLast(suffix.count))
        }
        return metro
    }
}

extension String {
    fileprivate var trimmed: String {
        trimmingCharacters(in: .whitespaces)
    }
}
