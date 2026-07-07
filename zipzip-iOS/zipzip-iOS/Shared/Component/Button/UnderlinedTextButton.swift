//
//  UnderlinedTextButton.swift
//  zipzip-iOS
//
//  Created by Codex on 7/7/26.
//

import SwiftUI

struct UnderlinedTextButton: View {
    enum Style {
        case medium
        case small
    }

    let title: String
    var style: Style = .medium
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .foregroundStyle(foregroundColor)
                .underline()
                .lineLimit(1)
        }
        .buttonStyle(.plain)
    }

    private var font: Font {
        switch style {
        case .medium: .b1_md
        case .small: .b3_sb
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .medium: .grey400
        case .small: .grey500
        }
    }
}

#Preview("Underlined Text Button") {
    VStack(spacing: 16) {
        UnderlinedTextButton(
            title: "목록에 내 기기가 없어요",
            style: .medium
        ) {}

        UnderlinedTextButton(
            title: "수정",
            style: .small
        ) {}
    }
}
