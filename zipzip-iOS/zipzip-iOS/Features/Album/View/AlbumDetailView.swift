//
//  AlbumDetailView.swift
//  zipzip-iOS
//
//  Created by mansuiki on 7/8/26.
//

import SwiftUI

struct AlbumDetailItem: Hashable, Identifiable {
    let id = UUID()
    let title: String
    let createdAt: Date
    let photoCount: Int
}

struct AlbumDetailView<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    let album: AlbumDetailItem
    private let contentTopSpacing: CGFloat
    private let detailContent: Content

    init(
        album: AlbumDetailItem,
        contentTopSpacing: CGFloat = 30,
        @ViewBuilder content: () -> Content
    ) {
        self.album = album
        self.contentTopSpacing = contentTopSpacing
        self.detailContent = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.orange30
                .ignoresSafeArea()

            scrollContent
        }
        .overlay(alignment: .topLeading) {
            RoundedIconButton(items: [
                .init(id: "back", icon: .iconChevronLeft) {
                    dismiss()
                }
            ])
            .padding(.top, 19)
            .padding(.leading, 16)
        }
        .overlay(alignment: .topTrailing) {
            AlbumHeaderActionButton(
                onSelectionTap: {},
                onAddTap: {}
            )
            .padding(.top, 19)
            .padding(.trailing, 16)
        }
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: contentTopSpacing) {
                titleSection

                detailContent
            }
            .padding(.top, 168)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(alignment: .top) {
                AlbumDetailFolderBackground()
                    .ignoresSafeArea()
            }
        }
    }

    private var titleSection: some View {
        AlbumDetailTitleSection(album: album)
    }
}

struct AlbumDetailEmptyView: View {
    let album: AlbumDetailItem

    var body: some View {
        AlbumDetailView(album: album, contentTopSpacing: 125) {
            AlbumDetailEmptyContent()
        }
    }
}

private struct AlbumDetailTitleSection: View {
    let album: AlbumDetailItem

    var body: some View {
        VStack(spacing: 2) {
            Text(album.title)
                .font(.t1_sb)
                .foregroundStyle(.grey1000)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(.calendar)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.grey400)
                    .frame(width: 16, height: 16)

                Text(dateText)
                    .font(.b2_md)
                    .foregroundStyle(.grey400)
            }
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. M. d"
        return formatter.string(from: album.createdAt)
    }
}

private struct AlbumDetailEmptyContent: View {
    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(.grey100)
                .frame(width: 80, height: 80)

            Text("사진집에 사진을 넣어볼까요?")
                .font(.t2_md)
                .foregroundStyle(.grey1000)
                .multilineTextAlignment(.center)
        }
    }
}

struct AlbumDetailGalleryPlaceholderView: View {
    let photoCount: Int

    private let sections: [AlbumDetailGallerySection] = [
        .init(title: "오늘", itemCount: 8),
        .init(title: "어제", itemCount: 8),
        .init(title: "7월 1일", itemCount: 8),
        .init(title: "6월 30일", itemCount: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            totalCount

            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(sections) { section in
                    AlbumDetailGallerySectionView(section: section)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var totalCount: some View {
        HStack(spacing: 6) {
            Text("총")
            Text("\(photoCount)장")
        }
        .font(.b2_md)
        .foregroundStyle(.grey800)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AlbumDetailGallerySection: Identifiable {
    let title: String
    let itemCount: Int

    var id: String {
        title
    }
}

private struct AlbumDetailGallerySectionView: View {
    let section: AlbumDetailGallerySection

    private let columns = Array(
        repeating: GridItem(.fixed(88), spacing: 2),
        count: 4
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.b2_sb)
                .foregroundStyle(.grey1000)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 2) {
                ForEach(0 ..< section.itemCount, id: \.self) { _ in
                    Rectangle()
                        .fill(.grey200)
                        .frame(width: 88, height: 88)
                }
            }
        }
    }
}

private struct AlbumDetailFolderBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let topOffset: CGFloat = 68
            let width = proxy.size.width + 6
            let height = width * AlbumDetailFolderShape.referenceHeight / AlbumDetailFolderShape.referenceWidth

            AlbumDetailFolderShape()
                .fill(.grey50)
                .overlay {
                    AlbumDetailFolderShape()
                        .stroke(.grey70, lineWidth: 4)
                }
                .frame(width: width, height: height)
                .offset(x: -3, y: topOffset)
        }
        .allowsHitTesting(false)
    }
}

private struct AlbumDetailFolderShape: Shape {
    static let referenceWidth: CGFloat = 396
    static let referenceHeight: CGFloat = 797

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + x / Self.referenceWidth * rect.width,
                y: rect.minY + y / Self.referenceHeight * rect.height
            )
        }

        var path = Path()

        path.move(to: point(262.33, 2.54639))
        path.addCurve(
            to: point(271.422, 3.87744),
            control1: point(265.397, 1.48902),
            control2: point(268.787, 1.98521)
        )
        path.addLine(to: point(389.833, 88.9019))
        path.addCurve(
            to: point(394, 97.0239),
            control1: point(392.449, 90.7803),
            control2: point(394, 93.8035)
        )
        path.addLine(to: point(394, 784.632))
        path.addCurve(
            to: point(384, 794.632),
            control1: point(394, 790.155),
            control2: point(389.523, 794.632)
        )
        path.addLine(to: point(12, 794.632))
        path.addCurve(
            to: point(2, 784.632),
            control1: point(6.47716, 794.632),
            control2: point(2, 790.155)
        )
        path.addLine(to: point(2, 99.4243))
        path.addCurve(
            to: point(8.74121, 89.9702),
            control1: point(2, 95.1577),
            control2: point(4.70753, 91.3608)
        )
        path.addLine(to: point(262.33, 2.54639))
        path.closeSubpath()

        return path
    }
}

#Preview("Album Detail Empty", traits: .fixedLayout(width: 390, height: 844)) {
    AlbumDetailEmptyView(
        album: .init(
            title: "집집 🏠",
            createdAt: .now,
            photoCount: 0
        )
    )
}

#Preview("Album Detail Gallery", traits: .fixedLayout(width: 390, height: 844)) {
    AlbumDetailView(
        album: .init(
            title: "집집 🏠",
            createdAt: .now,
            photoCount: 123
        )
    ) {
        AlbumDetailGalleryPlaceholderView(photoCount: 123)
    }
}
