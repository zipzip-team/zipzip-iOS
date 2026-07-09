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
    @State private var isSelectionMode: Bool

    let album: AlbumDetailItem
    private let contentTopSpacing: CGFloat
    private let detailContent: (Bool) -> Content

    init(
        album: AlbumDetailItem,
        contentTopSpacing: CGFloat = 30,
        initialSelectionMode: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.album = album
        self.contentTopSpacing = contentTopSpacing
        _isSelectionMode = State(initialValue: initialSelectionMode)
        self.detailContent = { _ in content() }
    }

    init(
        album: AlbumDetailItem,
        contentTopSpacing: CGFloat = 30,
        initialSelectionMode: Bool = false,
        @ViewBuilder content: @escaping (Bool) -> Content
    ) {
        self.album = album
        self.contentTopSpacing = contentTopSpacing
        _isSelectionMode = State(initialValue: initialSelectionMode)
        self.detailContent = content
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.orange30
                .ignoresSafeArea()

            scrollContent
        }
        .overlay(alignment: .topLeading) {
            leadingActionButton
                .padding(.top, 19)
                .padding(.leading, 16)
        }
        .overlay(alignment: .topTrailing) {
            AlbumHeaderActionButton(
                onSelectionTap: enterSelectionMode,
                onAddTap: loadAlbumDetailPhotos
            )
            .padding(.top, 19)
            .padding(.trailing, 16)
            .opacity(isSelectionMode ? 0 : 1)
            .allowsHitTesting(!isSelectionMode)
            .accessibilityHidden(isSelectionMode)
        }
        .overlay(alignment: .bottom) {
            if isSelectionMode {
                ActionBar(items: selectionActionItems)
                    .padding(.bottom, 49)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: contentTopSpacing) {
                titleSection

                detailContent(isSelectionMode)
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

    private var selectionActionItems: [ActionBarItem] {
        [
            .init(icon: .moveToAlbum, title: "집 관리", action: manageAlbum),
            .init(icon: .chevronRight, title: "이동하기", isDisabled: true) {},
            .init(icon: .metadata, title: "정보 수정", isDisabled: true) {},
            .init(icon: .delete, title: "삭제", isDisabled: true) {}
        ]
    }

    @ViewBuilder private var leadingActionButton: some View {
        if isSelectionMode {
            RoundedTextButton(title: "취소", style: .cancel, action: exitSelectionMode)
        } else {
            RoundedIconButton(items: [
                .init(id: "back", icon: .iconChevronLeft) {
                    dismiss()
                }
            ])
        }
    }

    private func enterSelectionMode() {
        guard album.photoCount > 0 else {
            return
        }

        isSelectionMode = true
    }

    private func exitSelectionMode() {
        isSelectionMode = false
    }

    private func manageAlbum() {}
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
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Rectangle()
                    .fill(.grey100)
                    .frame(width: 80, height: 80)

                Image(.albumEmptyDescription)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 246, height: 20)
                    .accessibilityLabel("사진집에 사진을 넣어볼까요?")
            }

            CommonButton(
                title: "사진 불러오기",
                property1: .default,
                property2: .pressed,
                action: loadAlbumDetailPhotos
            )
            .frame(width: 171)
        }
    }
}

struct AlbumDetailGalleryPlaceholderView: View {
    @State private var selectedPhotoIDs: [UUID] = []

    let photoCount: Int
    var showsSelectionControls = false

    private let sections = PhotoSection.sample

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            totalCount

            PhotoGallery(
                sections: sections,
                isSelectionMode: showsSelectionControls,
                selectedPhotoIDs: selectedPhotoIDs,
                onTapPhoto: toggleSelection
            )
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: showsSelectionControls) { _, newValue in
            if !newValue {
                selectedPhotoIDs.removeAll()
            }
        }
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

    private func toggleSelection(_ id: UUID) {
        guard showsSelectionControls else {
            return
        }

        if let index = selectedPhotoIDs.firstIndex(of: id) {
            selectedPhotoIDs.remove(at: index)
        } else {
            selectedPhotoIDs.append(id)
        }
    }
}

private struct AlbumDetailFolderBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let topOffset: CGFloat = 68
            let width = proxy.size.width + 6
            let referenceHeight = width * AlbumDetailFolderShape.referenceHeight / AlbumDetailFolderShape.referenceWidth
            let height = max(referenceHeight, proxy.size.height - topOffset + 16)

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
    private static let referenceBottomLineY: CGFloat = 794.632
    private static let referenceSideBottomY: CGFloat = 784.632

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let scale = rect.width / Self.referenceWidth
            return CGPoint(
                x: rect.minX + x * scale,
                y: rect.minY + y * scale
            )
        }

        func xPosition(_ x: CGFloat) -> CGFloat {
            let scale = rect.width / Self.referenceWidth
            return rect.minX + x * scale
        }

        let scale = rect.width / Self.referenceWidth
        let bottomLineY = rect.maxY - (Self.referenceHeight - Self.referenceBottomLineY) * scale
        let sideBottomY = bottomLineY - (Self.referenceBottomLineY - Self.referenceSideBottomY) * scale

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
        path.addLine(to: CGPoint(x: xPosition(394), y: sideBottomY))
        path.addCurve(
            to: CGPoint(x: xPosition(384), y: bottomLineY),
            control1: CGPoint(
                x: xPosition(394),
                y: sideBottomY + (790.155 - Self.referenceSideBottomY) * scale
            ),
            control2: CGPoint(x: xPosition(389.523), y: bottomLineY)
        )
        path.addLine(to: CGPoint(x: xPosition(12), y: bottomLineY))
        path.addCurve(
            to: CGPoint(x: xPosition(2), y: sideBottomY),
            control1: CGPoint(x: xPosition(6.47716), y: bottomLineY),
            control2: CGPoint(
                x: xPosition(2),
                y: sideBottomY + (790.155 - Self.referenceSideBottomY) * scale
            )
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

private func loadAlbumDetailPhotos() {}

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

#Preview("Album Detail Selection", traits: .fixedLayout(width: 390, height: 844)) {
    AlbumDetailView(
        album: .init(
            title: "집집 🏠",
            createdAt: .now,
            photoCount: 123
        ),
        initialSelectionMode: true
    ) { isSelectionMode in
        AlbumDetailGalleryPlaceholderView(
            photoCount: 123,
            showsSelectionControls: isSelectionMode
        )
    }
}
