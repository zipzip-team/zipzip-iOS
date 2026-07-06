//
//  RoundedIconButton.swift
//  zipzip-iOS
//
//  Created by Codex on 7/6/26.
//

import SwiftUI

struct RoundedIconButton: View {
    let items: [RoundedIconButtonItem]

    init(items: [RoundedIconButtonItem]) {
        precondition((1 ... 3).contains(items.count), "RoundedIconButton supports 1 to 3 items.")
        self.items = items
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                button(for: item)

                if index < items.count - 1 {
                    Rectangle()
                        .fill(.grey50)
                        .frame(width: 1, height: 36)
                }
            }
        }
        .padding(.horizontal, items.count == 1 ? 8 : 4)
        .frame(height: 44)
        .background(.white00, in: .capsule)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 4)
    }

    private func button(for item: RoundedIconButtonItem) -> some View {
        Button(action: item.action) {
            Image(item.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .padding(.horizontal, items.count == 1 ? 8 : 12)
                .frame(height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Rounded Icon Button") {
    VStack(spacing: 16) {
        RoundedIconButton(items: [
            .init(icon: .iconChevronLeft) {
                print("뒤로가기 버튼 선택")
            }
        ])

        RoundedIconButton(items: [
            .init(icon: .iconFilter) {},
            .init(icon: .iconSelection) {}
        ])

        RoundedIconButton(items: [
            .init(icon: .iconFilter) {},
            .init(icon: .iconSelection) {},
            .init(icon: .iconFilter) {}
        ])
    }
    .padding()
    .background(.grey100)
}
