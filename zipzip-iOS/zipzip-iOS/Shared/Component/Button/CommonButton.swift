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
        case cta
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
                .foregroundStyle(.white00)
                .padding(.horizontal, 40)
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
    }
}

private struct CommonButtonStyle: ButtonStyle {
    let property1: CommonButton.Property1
    let property2: CommonButton.Property2

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(.rect(cornerRadius: 12))
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        let isPressed = isPressed || property2 == .pressed

        return switch (property1, isPressed) {
        case (.default, false): Color.grey950
        case (.default, true): Color.grey900
        case (.cta, false): Color.orange500
        case (.cta, true): Color.orange700
        }
    }
}

#Preview("Common Button") {
    CommonButton(title: "시작하기") {}
        .padding(12)
    CommonButton(title: "시작하기", property1: .cta) {}
        .padding(12)
}
