//
//  Font+.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/4/26.
//

import SwiftUI

extension Font {
    static func pretendard(size fontSize: CGFloat, weight: Font.Weight) -> Font {
        let familyName = "Pretendard"
        let weightMap: [(Font.Weight, String)] = [
            (.black, "Black"),
            (.bold, "Bold"),
            (.heavy, "ExtraBold"),
            (.ultraLight, "ExtraLight"),
            (.light, "Light"),
            (.medium, "Medium"),
            (.regular, "Regular"),
            (.semibold, "SemiBold"),
            (.thin, "Thin")
        ]
        let weightString = weightMap.first { $0.0 == weight }?.1 ?? "Regular"
        return Font.custom("\(familyName)-\(weightString)", size: fontSize)
    }

    static let h1_sb = Font.pretendard(size: 26, weight: .semibold)

    static let t1_sb = Font.pretendard(size: 22, weight: .semibold)
    static let t1_md = Font.pretendard(size: 22, weight: .medium)
    static let t2_sb = Font.pretendard(size: 20, weight: .semibold)
    static let t2_md = Font.pretendard(size: 20, weight: .medium)
    static let t3_sb = Font.pretendard(size: 18, weight: .semibold)
    static let t3_md = Font.pretendard(size: 18, weight: .medium)

    static let b1_sb = Font.pretendard(size: 16, weight: .semibold)
    static let b1_md = Font.pretendard(size: 16, weight: .medium)
    static let b2_sb = Font.pretendard(size: 14, weight: .semibold)
    static let b2_md = Font.pretendard(size: 14, weight: .medium)
    static let b3_sb = Font.pretendard(size: 12, weight: .semibold)
    static let b3_md = Font.pretendard(size: 12, weight: .medium)

    static let n1_sb = Font.pretendard(size: 16, weight: .semibold)
    static let n2_sb = Font.pretendard(size: 14, weight: .semibold)
    static let n3_md = Font.pretendard(size: 12, weight: .medium)
}
