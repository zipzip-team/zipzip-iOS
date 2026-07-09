//
//  RoundedIconButton.swift
//  zipzip-iOS
//
//  Created by Codex on 7/6/26.
//

import SwiftUI

struct RoundedIconButton: View {
    private let items: [RoundedIconButtonItem]

    init(items: [RoundedIconButtonItem]) {
        if items.isEmpty {
            assertionFailure("RoundedIconButton requires at least 1 item.")
            self.items = []
        } else if items.count > 3 {
            assertionFailure("RoundedIconButton supports up to 3 items.")
            self.items = Array(items.prefix(3))
        } else {
            self.items = items
        }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyView()
            } else {
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
        }
    }

    @ViewBuilder private func button(for item: RoundedIconButtonItem) -> some View {
        let button = Button(action: item.action) {
            Image(item.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.grey1000)
                .frame(width: 28, height: 28)
                .padding(.horizontal, items.count == 1 ? 8 : 12)
                .frame(height: 44)
                .contentShape(.rect)
                .accessibilityHidden(item.accessibilityLabel != nil)
        }
        .buttonStyle(.plain)

        if let accessibilityLabel = item.accessibilityLabel {
            button.accessibilityLabel(accessibilityLabel)
        } else {
            button
        }
    }
}

#Preview("Rounded Icon Button") {
    VStack(spacing: 16) {
        RoundedIconButton(items: [
            .init(id: "back", icon: .iconChevronLeft) {
                print("뒤로가기 버튼 선택")
            }
        ])

        RoundedIconButton(items: [
            .init(id: "filter", icon: .iconFilter) {},
            .init(id: "selection", icon: .iconSelection) {}
        ])

        RoundedIconButton(items: [
            .init(id: "filter", icon: .iconFilter) {},
            .init(id: "selection", icon: .iconSelection) {},
            .init(id: "filter-secondary", icon: .iconFilter) {}
        ])
    }
    .padding()
    .background(.grey100)
}
