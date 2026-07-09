//
//  ActionBar.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/6/26.
//

import SwiftUI

struct ActionBar: View {
    let items: [ActionBarItem]

    private var itemWidth: CGFloat {
        items.count <= 3 ? 100 : 84
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
                iconView(item.icon, isDisabled: item.isDisabled)
                Text(item.title)
                    .font(.b2_md)
                    .foregroundStyle(item.isDisabled ? .grey700 : .grey50)
                    .fixedSize()
            }
            .frame(width: itemWidth)
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
        .disabled(item.isDisabled)
    }

    @ViewBuilder
    private func iconView(_ icon: ImageResource?, isDisabled: Bool) -> some View {
        if let icon {
            Image(icon)
                .resizable()
                .renderingMode(isDisabled ? .template : .original)
                .foregroundStyle(.grey700)
                .frame(width: 24, height: 24)
                .frame(width: 32, height: 32)
        } else {
            Rectangle()
                .fill(.grey800)
                .frame(width: 24, height: 24)
                .frame(width: 32, height: 32)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ActionBar(items: [
            .init(icon: .delete, title: "삭제") {}
        ])
        ActionBar(items: [
            .init(icon: .moveToAlbum, title: "사진집으로") {},
            .init(icon: .delete, title: "삭제") {}
        ])
        ActionBar(items: [
            .init(icon: .moveToAlbum, title: "사진집으로") {},
            .init(icon: .metadata, title: "정보 수정") {},
            .init(icon: .delete, title: "삭제") {}
        ])
        ActionBar(items: [
            .init(icon: .starStroke, title: "즐겨찾기") {},
            .init(icon: .moveToAlbum, title: "사진집으로", isDisabled: true) {},
            .init(icon: .metadata, title: "정보 수정") {},
            .init(icon: .delete, title: "삭제") {}
        ])
    }
    .padding()
    .background(.orange30)
}
