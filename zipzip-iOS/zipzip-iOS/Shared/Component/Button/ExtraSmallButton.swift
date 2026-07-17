//
//  ExtraSmallButton.swift
//  zipzip-iOS
//
//  Created by Codex on 7/7/26.
//

import SwiftUI

struct ExtraSmallButton: View {
    @Environment(\.isEnabled) private var isEnabled

    private enum Content {
        case icon(ImageResource)
        case text(String)
    }

    private let content: Content
    private let action: () -> Void

    init(
        icon: ImageResource,
        action: @escaping () -> Void
    ) {
        self.content = .icon(icon)
        self.action = action
    }

    init(
        title: String,
        action: @escaping () -> Void
    ) {
        self.content = .text(title)
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            label
                .padding(14)
                .background(isEnabled ? .orange500 : .grey900, in: .rect(cornerRadius: 12))
                .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var label: some View {
        switch content {
        case let .icon(icon):
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(isEnabled ? .white00 : .grey600)
                .frame(width: 24, height: 24)

        case let .text(title):
            Text(title)
                .font(.b2_sb)
                .foregroundStyle(isEnabled ? .white00 : .grey600)
                .lineLimit(1)
        }
    }
}

#Preview("Extra Small Button") {
    HStack(spacing: 16) {
        ExtraSmallButton(icon: .send) {
            print("action은 이곳에 !!")
        }

        ExtraSmallButton(title: "확인") {}
    }
}
