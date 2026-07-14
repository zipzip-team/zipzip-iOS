//
//  AlbumDetailView.swift
//  zipzip-iOS
//
//  Created by mansuiki on 7/8/26.
//

import SwiftUI
import UIKit

struct AlbumDetailItem: Hashable, Identifiable {
    let id: Int
    let title: String
    let createdAt: Date
    let photoCount: Int
}

struct AlbumDetailView<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AlbumDetailViewModel

    let album: AlbumDetailItem
    private let contentTopSpacing: CGFloat
    private let detailContent: (AlbumDetailViewModel) -> Content
    private let moveAlbums: [Album]
    private let shareAlbums: [ShareAlbum]
    private let onOpenShareAlbum: (ShareAlbum.ID) async -> Void

    init(
        album: AlbumDetailItem,
        viewModel: AlbumDetailViewModel,
        contentTopSpacing: CGFloat = 30,
        moveAlbums: [Album] = [],
        shareAlbums: [ShareAlbum] = [],
        onOpenShareAlbum: @escaping (ShareAlbum.ID) async -> Void = { _ in },
        @ViewBuilder content: @escaping (AlbumDetailViewModel) -> Content
    ) {
        self.album = album
        _viewModel = State(initialValue: viewModel)
        self.contentTopSpacing = contentTopSpacing
        self.detailContent = content
        self.moveAlbums = moveAlbums
        self.shareAlbums = shareAlbums
        self.onOpenShareAlbum = onOpenShareAlbum
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.orange30
                .ignoresSafeArea()

            scrollContent
                .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .topLeading) {
            FloatingHeader(.leading) {
                leadingActionButton
            }
        }
        .overlay(alignment: .topLeading) {
            FloatingHeader(.trailing) {
                AlbumHeaderActionButton(
                    onSelectionTap: { viewModel.enterSelectionMode(photoCount: album.photoCount) },
                    onAddTap: viewModel.presentPhotoPicker
                )
                .opacity(viewModel.isSelectionMode ? 0 : 1)
                .allowsHitTesting(!viewModel.isSelectionMode)
                .accessibilityHidden(viewModel.isSelectionMode)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isSelectionMode {
                ActionBar(items: selectionActionItems)
                    .padding(.bottom, 49)
            }
        }
        .navigationDestination(isPresented: $viewModel.isPhotoPickerPresented) {
            AlbumPhotoPickerView(
                viewModel: AlbumPhotoPickerViewModel(
                    onComplete: viewModel.addPhotos
                )
            )
        }
        .bottomSheet(
            isPresented: $viewModel.isAlbumManagementPresented,
            detents: [.height(549)],
            initialDetent: .height(549),
            showsDragIndicator: .visible,
            expandsToLargestDetentOnScroll: false,
            onDismiss: viewModel.completeAlbumManagementDismissal
        ) { _ in
            BottomSheet(
                leftItem: {
                    BottomSheetCloseButton(action: viewModel.dismissAlbumManagement)
                },
                rightItem: {
                    AlbumManagementSheetHeaderButton(title: "삭제", action: viewModel.presentAlbumDeleteAlert)
                }
            ) {
                AlbumManagementSheetContent(
                    albumName: $viewModel.albumTitleDraft,
                    onCompleteTap: viewModel.completeAlbumManagement
                )
            }
        }
        .bottomSheetAlert(
            isPresented: $viewModel.isAlbumDeleteAlertPresented,
            title: "이 사진집을 삭제하시겠어요?",
            message: "사진집에 담긴 사진들은 삭제되지 않아요.",
            secondaryTitle: "취소",
            primaryTitle: "삭제",
            onSecondaryTap: viewModel.dismissAlbumDeleteAlert,
            onPrimaryTap: viewModel.confirmAlbumDeletion
        )
        .bottomSheet(isPresented: $viewModel.isMoveSheetPresented, detents: [.full]) { sheetDismiss in
            ShareSheet(
                albums: moveAlbums,
                shareAlbums: shareAlbums,
                onDismiss: { sheetDismiss() },
                excludedAlbumIDs: [album.id],
                onOpenShareAlbum: onOpenShareAlbum,
                onComplete: viewModel.completePhotoMove
            )
        }
        .bottomSheetAlert(
            isPresented: $viewModel.isDeleteAlertPresented,
            title: deleteAlertContent.title,
            message: deleteAlertContent.message,
            secondaryTitle: deleteAlertContent.secondaryTitle,
            primaryTitle: deleteAlertContent.primaryTitle,
            onSecondaryTap: viewModel.deleteSelectedPhotosPermanently,
            onPrimaryTap: viewModel.removeSelectedPhotosFromAlbum
        )
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: contentTopSpacing) {
                titleSection

                detailContent(viewModel)
            }
            .padding(.top, 166)
            .padding(.bottom, viewModel.isSelectionMode ? 140 : 40)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(alignment: .top) {
                AlbumDetailFolderBackground()
                    .ignoresSafeArea()
            }
        }
    }

    private var titleSection: some View {
        AlbumDetailTitleSection(title: albumTitle, createdAt: album.createdAt)
    }

    private var albumTitle: String {
        album.title
    }

    private var selectionActionItems: [ActionBarItem] {
        return [
            .init(icon: .settingAlbum, title: "집 관리") {
                viewModel.presentAlbumManagement(albumTitle: album.title)
            },
            .init(
                icon: .move,
                title: "이동하기",
                isDisabled: !viewModel.hasSelectedPhotos,
                action: viewModel.presentMoveSheet
            ),
            .init(
                icon: .metadata,
                title: "정보 수정",
                isDisabled: !viewModel.hasSelectedPhotos,
                action: viewModel.editSelectedPhotoInfo
            ),
            .init(
                icon: .delete,
                title: "삭제",
                isDisabled: !viewModel.hasSelectedPhotos,
                action: viewModel.presentPhotoDeleteAlert
            )
        ]
    }

    private var deleteAlertContent: PhotoDeleteAlertContent {
        PhotoDeletionContext.album.alertContent
    }

    @ViewBuilder private var leadingActionButton: some View {
        if viewModel.isSelectionMode {
            RoundedTextButton(title: "취소", style: .cancel, action: viewModel.exitSelectionMode)
        } else {
            RoundedIconButton(items: [
                .init(id: "back", icon: .iconChevronLeft, accessibilityLabel: "뒤로가기") {
                    dismiss()
                }
            ])
        }
    }
}

struct AlbumDetailEmptyView: View {
    let album: AlbumDetailItem
    let viewModel: AlbumDetailViewModel
    var moveAlbums: [Album] = []
    var shareAlbums: [ShareAlbum] = []
    var onOpenShareAlbum: (ShareAlbum.ID) async -> Void = { _ in }

    var body: some View {
        AlbumDetailView(
            album: album,
            viewModel: viewModel,
            contentTopSpacing: 125,
            moveAlbums: moveAlbums,
            shareAlbums: shareAlbums,
            onOpenShareAlbum: onOpenShareAlbum
        ) { viewModel in
            AlbumDetailEmptyContent(onLoadPhotos: viewModel.presentPhotoPicker)
        }
    }
}

private struct AlbumDetailTitleSection: View {
    let title: String
    let createdAt: Date

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
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
        return formatter.string(from: createdAt)
    }
}

private struct AlbumManagementSheetHeaderButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.b1_sb)
                .foregroundStyle(.white00)
                .frame(width: 72, height: 48)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct AlbumManagementSheetContent: View {
    @Binding var albumName: String

    let onCompleteTap: () -> Void

    var body: some View {
        VStack(spacing: 34) {
            AlbumFolder(state: .plain) {
                EmptyView()
            }
            .accessibilityHidden(true)

            VStack(spacing: 49) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("사진집 이름")
                        .font(.t3_md)
                        .foregroundStyle(.grey300)

                    TextInput("이름 입력", text: $albumName)
                }

                CommonButton(
                    title: "완료",
                    property1: isCompletionDisabled ? .disabled : .cta,
                    action: onCompleteTap
                )
            }
            .frame(maxWidth: 358)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var isCompletionDisabled: Bool {
        albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct AlbumDetailEmptyContent: View {
    let onLoadPhotos: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Image(.albumDetailEmptyArtwork)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .accessibilityHidden(true)

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
                action: onLoadPhotos
            )
            .frame(width: 171)
        }
    }
}

struct AlbumDetailGalleryPlaceholderView: View {
    let photoCount: Int
    var showsSelectionControls = false

    private let sections: [PhotoSection]
    private let selectedPhotoIDs: [UUID]
    private let onSelectPhoto: (UUID) -> Void
    private let onOpenPhoto: ((Photo) -> Void)?

    @State private var thumbnailImages: [String: UIImage] = [:]
    @State private var loadingIdentifiers: Set<String> = []

    private static let thumbnailSize = CGSize(width: 300, height: 300)

    init(
        sections: [PhotoSection] = PhotoSection.sample,
        photoCount: Int,
        showsSelectionControls: Bool = false,
        selectedPhotoIDs: [UUID] = [],
        onSelectPhoto: @escaping (UUID) -> Void = { _ in },
        onOpenPhoto: ((Photo) -> Void)? = nil
    ) {
        self.sections = sections
        self.photoCount = photoCount
        self.showsSelectionControls = showsSelectionControls
        self.selectedPhotoIDs = selectedPhotoIDs
        self.onSelectPhoto = onSelectPhoto
        self.onOpenPhoto = onOpenPhoto
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            totalCount

            PhotoGallery(
                sections: sections,
                thumbnailImages: thumbnailImages,
                loadThumbnail: loadThumbnail,
                isSelectionMode: showsSelectionControls,
                selectedPhotoIDs: selectedPhotoIDs,
                onTapPhoto: onSelectPhoto,
                onOpenPhoto: onOpenPhoto
            )
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadThumbnail(_ localIdentifier: String) async {
        guard !localIdentifier.isEmpty,
              thumbnailImages[localIdentifier] == nil,
              !loadingIdentifiers.contains(localIdentifier)
        else {
            return
        }

        loadingIdentifiers.insert(localIdentifier)
        defer { loadingIdentifiers.remove(localIdentifier) }

        let image = await PhotoThumbnailLoader.shared.thumbnail(
            for: localIdentifier,
            targetSize: Self.thumbnailSize
        )
        guard !Task.isCancelled, let image else {
            return
        }

        thumbnailImages[localIdentifier] = image
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

#Preview("Album Detail Empty", traits: .fixedLayout(width: 390, height: 844)) {
    AlbumDetailEmptyView(
        album: .init(
            id: 1,
            title: "집집 🏠",
            createdAt: .now,
            photoCount: 0
        ),
        viewModel: AlbumDetailViewModel()
    )
}

#Preview("Album Detail Gallery", traits: .fixedLayout(width: 390, height: 844)) {
    AlbumDetailView(
        album: .init(
            id: 2,
            title: "집집 🏠",
            createdAt: .now,
            photoCount: 123
        ),
        viewModel: AlbumDetailViewModel()
    ) { _ in
        AlbumDetailGalleryPlaceholderView(photoCount: 123)
    }
}

#Preview("Album Detail Selection", traits: .fixedLayout(width: 390, height: 844)) {
    AlbumDetailView(
        album: .init(
            id: 3,
            title: "집집 🏠",
            createdAt: .now,
            photoCount: 123
        ),
        viewModel: AlbumDetailViewModel(initialSelectionMode: true)
    ) { viewModel in
        AlbumDetailGalleryPlaceholderView(
            photoCount: 123,
            showsSelectionControls: viewModel.isSelectionMode,
            selectedPhotoIDs: viewModel.selectedPhotoIDs,
            onSelectPhoto: viewModel.togglePhotoSelection
        )
    }
}
