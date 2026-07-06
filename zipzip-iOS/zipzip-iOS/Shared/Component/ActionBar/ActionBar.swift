//
//  ActionBar.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/6/26.
//

import SwiftUI

struct ActionBar: View {
    let items: [ActionBarItem]

    private var horizontalPadding: CGFloat {
        items.count <= 3 ? 24 : 16
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                itemView(item, isLast: index == items.count - 1)
            }
        }
        .padding(4)
        .background(.grey950, in: .capsule)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 1)
    }

    private func itemView(_ item: ActionBarItem, isLast: Bool) -> some View {
        Button {
            item.action()
        } label: {
            VStack(spacing: 0) {
                iconView(item.icon)
                Text(item.title)
                    .font(.b2_md)
                    .foregroundStyle(.grey50)
                    .fixedSize()
            }
            .frame(minWidth: 52)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 2)
            .overlay(alignment: .trailing) {
                if !isLast {
                    Rectangle()
                        .fill(.grey900)
                        .frame(width: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func iconView(_ icon: ImageResource?) -> some View {
        if let icon {
            Image(icon)
                .resizable()
                .frame(width: 32, height: 32)
        } else {
            Rectangle()
                .fill(.grey800)
                .frame(width: 24, height: 24)
                .frame(width: 32, height: 32)
        }
    }
}
