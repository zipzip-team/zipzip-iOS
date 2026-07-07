//
//  Typography.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/8/26.
//

import SwiftUI
import UIKit

struct Typography {
    let size: CGFloat
    let weight: Font.Weight
    let lineHeightMultiple: CGFloat

    var font: Font {
        .pretendard(size: size, weight: weight)
    }

    var lineSpacing: CGFloat {
        let natural = Pretendard.uiFont(size: size, weight: weight).lineHeight
        return max(0, size * lineHeightMultiple - natural)
    }
}

extension View {
    func font(_ style: Typography) -> some View {
        font(style.font)
            .lineSpacing(style.lineSpacing)
    }
}

extension Typography {
    static let h1_sb = Typography(size: 26, weight: .semibold, lineHeightMultiple: 1.5)

    static let t1_sb = Typography(size: 22, weight: .semibold, lineHeightMultiple: 1.5)
    static let t1_md = Typography(size: 22, weight: .medium, lineHeightMultiple: 1.5)
    static let t2_sb = Typography(size: 20, weight: .semibold, lineHeightMultiple: 1.5)
    static let t2_md = Typography(size: 20, weight: .medium, lineHeightMultiple: 1.5)
    static let t3_sb = Typography(size: 18, weight: .semibold, lineHeightMultiple: 1.5)
    static let t3_md = Typography(size: 18, weight: .medium, lineHeightMultiple: 1.5)

    static let b1_sb = Typography(size: 16, weight: .semibold, lineHeightMultiple: 1.5)
    static let b1_md = Typography(size: 16, weight: .medium, lineHeightMultiple: 1.5)
    static let b2_sb = Typography(size: 14, weight: .semibold, lineHeightMultiple: 1.5)
    static let b2_md = Typography(size: 14, weight: .medium, lineHeightMultiple: 1.5)
    static let b3_sb = Typography(size: 12, weight: .semibold, lineHeightMultiple: 1.5)
    static let b3_md = Typography(size: 12, weight: .medium, lineHeightMultiple: 1.5)

    static let n1_sb = Typography(size: 16, weight: .semibold, lineHeightMultiple: 1.0)
    static let n2_sb = Typography(size: 14, weight: .semibold, lineHeightMultiple: 1.0)
    static let n3_md = Typography(size: 12, weight: .medium, lineHeightMultiple: 1.0)
}
