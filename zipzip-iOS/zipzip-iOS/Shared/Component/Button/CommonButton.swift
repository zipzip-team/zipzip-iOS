//
//  CommonButton.swift
//  zipzip-iOS
//
//  Created by Codex on 7/6/26.
//

import SwiftUI

struct CommonButton: View {
    enum Property1 {
        case `default`
        case secondary
        case cta
        case disabled
    }

    enum Property2 {
        case `default`
        case pressed
    }

    let title: String
    var property1: Property1 = .default
    var property2: Property2 = .default
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.t3_sb)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .contentShape(.rect)
        }
        .buttonStyle(
            CommonButtonStyle(
                property1: property1,
                property2: property2
            )
        )
        .disabled(property1 == .disabled)
    }
}

private struct CommonButtonStyle: ButtonStyle {
    let property1: CommonButton.Property1
    let property2: CommonButton.Property2

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                if property1 == .disabled {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.grey700, lineWidth: 1)
                }
            }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        let isPressed = isPressed || property2 == .pressed

        return switch (property1, isPressed) {
        case (.default, false): Color.grey950
        case (.default, true): Color.grey900
        case (.secondary, false): Color.grey300
        case (.secondary, true): Color.grey500
        case (.cta, false): Color.orange500
        case (.cta, true): Color.orange700
        case (.disabled, _): Color.clear
        }
    }

    private var foregroundColor: Color {
        property1 == .disabled ? .grey800 : .white00
    }
}

#Preview("Common Button") {
    VStack(spacing: 12) {
        CommonButton(title: "시작하기") {}
        HStack(spacing: 16){
            CommonButton(title: "삭제", property1: .secondary) {}
            CommonButton(title: "앨범에서 제거", property1: .cta) {}
        }
        CommonButton(title: "확인", property1: .disabled) {}
    }
    .padding(16)
}
