//
//  AlbumView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/5/26.
//

import SwiftUI

struct AlbumView: View {
    private let albums = AlbumViewItem.samples
    private let columns = [
        GridItem(.fixed(170), spacing: 17),
        GridItem(.fixed(170), spacing: 17)
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.orange30
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                AlbumTitleHeader()
                    .padding(.top, 15)
                    .frame(height: 67, alignment: .bottom)

                LazyVGrid(
                    columns: columns,
                    alignment: .center,
                    spacing: 20
                ) {
                    ForEach(albums) { album in
                        AlbumCard(
                            name: album.name,
                            count: album.count
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(album.name), \(album.count)장")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 17)
            }

            AlbumHeaderActionButton(
                onSelectionTap: {},
                onAddTap: {}
            )
            .padding(.top, 19)
            .padding(.trailing, 16)
        }
    }
}

private struct AlbumTitleHeader: View {
    var body: some View {
        Text("사진집")
            .font(.t1_sb)
            .foregroundStyle(.grey900)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
    }
}

private struct AlbumHeaderActionButton: View {
    let onSelectionTap: () -> Void
    let onAddTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            button(
                icon: .iconSelection,
                accessibilityLabel: "사진집 선택",
                action: onSelectionTap
            )

            Rectangle()
                .fill(.grey50)
                .frame(width: 1, height: 36)

            button(
                icon: .plus,
                accessibilityLabel: "사진집 추가",
                action: onAddTap
            )
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
        .background(.white00, in: .capsule)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 4)
    }

    private func button(
        icon: ImageResource,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.grey1000)
                .frame(width: 28, height: 28)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .contentShape(.rect)
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct AlbumViewItem: Identifiable, Equatable {
    let id: String
    let name: String
    let count: Int
}

extension AlbumViewItem {
    fileprivate static let samples: [AlbumViewItem] = [
        .init(id: "family", name: "우리 가족", count: 678),
        .init(id: "zipzip", name: "집집 🏠", count: 234),
        .init(id: "tokyo", name: "도쿄 여행 🍥", count: 456),
        .init(id: "sopt", name: "솝트", count: 1234),
        .init(id: "homi", name: "호미🐶", count: 45)
    ]
}

#Preview("Album View", traits: .fixedLayout(width: 390, height: 844)) {
    AlbumViewPreview()
}

private struct AlbumViewPreview: View {
    @State private var selection: NavbarTab = .album

    var body: some View {
        AlbumView()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Navbar(selection: $selection)
                    .padding(.bottom, 28)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
    }
}
