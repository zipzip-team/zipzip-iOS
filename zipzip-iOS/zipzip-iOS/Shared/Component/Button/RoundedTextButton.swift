//
//  RoundedTextButton.swift
//  zipzip-iOS
//
//  Created by Codex on 7/6/26.
//

import SwiftUI

struct RoundedTextButton: View {
    enum Style {
        case large
        case medium
        case cancel
    }

    let title: String
    var style: Style = .large
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .foregroundStyle(.white00)
                .lineLimit(1)
                .padding(.horizontal, horizontalPadding)
                .frame(height: height)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(backgroundColor, in: .capsule)
        .shadow(color: shadowColor, radius: 6, y: 4)
    }

    private var font: Font {
        switch style {
        case .large, .medium: .b1_md
        case .cancel: .b1_sb
        }
    }

    private var horizontalPadding: CGFloat {
        switch style {
        case .large: 20
        case .medium: 12
        case .cancel: 14
        }
    }

    private var height: CGFloat {
        switch style {
        case .large: 40
        case .medium: 36
        case .cancel: 44
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .large: .grey800
        case .medium, .cancel: .grey950
        }
    }

    private var shadowColor: Color {
        style == .cancel ? .black.opacity(0.05) : .clear
    }
}

#Preview("Rounded Text Button") {
    VStack(spacing: 16) {
        RoundedTextButton(title: "복사", style: .large) {
            print("복사 버튼 선택")
        }

        RoundedTextButton(title: "4:20 AM", style: .medium) {
            print("시간 버튼 선택")
        }

        RoundedTextButton(title: "취소", style: .cancel) {
            print("취소 버튼 선택")
        }
    }
    .padding()
    .background(.grey100)
}
