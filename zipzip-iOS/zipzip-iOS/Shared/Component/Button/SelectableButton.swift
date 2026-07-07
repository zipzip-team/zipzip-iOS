//
//  SelectableButton.swift
//  zipzip-iOS
//
//  Created by Codex on 7/7/26.
//

import SwiftUI

struct SelectableButton: View {
    let title: String
    let isSelected: Bool
    let selectedColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.b2_md)
                .foregroundStyle(isSelected ? Color.white00 : Color.grey1000)
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
                .background(backgroundColor, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var backgroundColor: Color {
        isSelected ? selectedColor : .grey50
    }
}

#Preview("Selectable Button") {
    VStack(spacing: 12) {
        SelectableButton(
            title: "개인",
            isSelected: false,
            selectedColor: .grey800
        ) {}

        SelectableButton(
            title: "개인",
            isSelected: true,
            selectedColor: .grey800
        ) {}

        SelectableButton(
            title: "개인",
            isSelected: true,
            selectedColor: .orange500
        ) {}
    }
    .padding()
}
