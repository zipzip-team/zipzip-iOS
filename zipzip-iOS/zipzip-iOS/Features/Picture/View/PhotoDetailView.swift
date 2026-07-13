//
//  PhotoDetailView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct PhotoDeleteAlertContent {
    let title: String
    let message: String
    let secondaryTitle: String
    let primaryTitle: String
}

enum PhotoDeletionContext {
    case gallery
    case album

    var alertContent: PhotoDeleteAlertContent {
        switch self {
        case .gallery:
            PhotoDeleteAlertContent(
                title: "이 사진을 삭제하시겠어요?",
                message: "삭제하면 집집과 사진 앱에서 모두 사라져요.",
                secondaryTitle: "취소",
                primaryTitle: "삭제"
            )
        case .album:
            PhotoDeleteAlertContent(
                title: "사진을 완전히 삭제할까요,\n아니면 사진집에서만 제거할까요?",
                message: "사진집에서 제거된 사진은 갤러리에 남아있어요",
                secondaryTitle: "삭제",
                primaryTitle: "사진집에서 제거"
            )
        }
    }
}

enum PhotoDeletionAction {
    case deletePermanently
    case removeFromAlbum
}

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var photo: Photo
    private let albums: [Album]
    let deletionContext: PhotoDeletionContext
    private let excludedAlbumIDs: Set<Album.ID>
    private let onDelete: (PhotoDeletionAction, Photo) async -> Bool
    private let onAddToAlbums: ([String], [ShareDestination]) -> Void
    private let onMoveToAlbums: ([Int], [ShareDestination]) -> Void
    private let loadIsFavorite: (String) async -> Bool
    private let onToggleFavorite: (String, Bool) -> Void

    @State private var isEditingInfo = false
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var isFavorite = false
    @State private var didToggleFavorite = false
    @State private var imageViewModel = PhotoDetailImageViewModel()
    @State private var photoScale: CGFloat = 1
    @State private var photoOffset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureOffset: CGSize = .zero

    private static let photoScrollAnchor = "photo-detail-image"
    private static let minimumPhotoScale: CGFloat = 1
    private static let maximumPhotoScale: CGFloat = 4
    private static let doubleTapPhotoScale: CGFloat = 2
    private static let zoomActivationThreshold: CGFloat = 1.01
    private static let infoRevealThreshold: CGFloat = 72

    init(
        photo: Photo,
        albums: [Album] = Album.samples,
        deletionContext: PhotoDeletionContext = .gallery,
        excludedAlbumIDs: Set<Album.ID> = [],
        onDelete: @escaping (PhotoDeletionAction, Photo) async -> Bool = { _, _ in true },
        onAddToAlbums: @escaping ([String], [ShareDestination]) -> Void = { _, _ in },
        onMoveToAlbums: @escaping ([Int], [ShareDestination]) -> Void = { _, _ in },
        loadIsFavorite: @escaping (String) async -> Bool = { _ in false },
        onToggleFavorite: @escaping (String, Bool) -> Void = { _, _ in }
    ) {
        _photo = State(initialValue: photo)
        self.albums = albums
        self.deletionContext = deletionContext
        self.excludedAlbumIDs = excludedAlbumIDs
        self.onDelete = onDelete
        self.onAddToAlbums = onAddToAlbums
        self.onMoveToAlbums = onMoveToAlbums
        self.loadIsFavorite = loadIsFavorite
        self.onToggleFavorite = onToggleFavorite
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                GeometryReader { geometry in
                    let collapsedPhotoHeight = geometry.size.width * 0.5
                    let infoPanelMinHeight = max(geometry.size.height - collapsedPhotoHeight, 0)
                    let currentPhotoScale = clampedPhotoScale(photoScale * gestureScale)
                    let currentPhotoOffset = clampedPhotoOffset(
                        adding: photoOffset,
                        and: gestureOffset,
                        in: geometry.size,
                        scale: currentPhotoScale
                    )

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            PhotoDetailImage(
                                image: imageViewModel.image,
                                contentMode: isEditingInfo ? .fill : .fit
                            )
                            .frame(
                                width: geometry.size.width,
                                height: isEditingInfo ? collapsedPhotoHeight : geometry.size.height
                            )
                            .scaleEffect(isEditingInfo ? Self.minimumPhotoScale : currentPhotoScale)
                            .offset(isEditingInfo ? .zero : currentPhotoOffset)
                            .clipped()
                            .contentShape(Rectangle())
                            .gesture(
                                photoGesture(in: geometry.size),
                                including: isEditingInfo ? .none : .all
                            )
                            .onTapGesture(count: 2) {
                                guard !isEditingInfo else { return }
                                togglePhotoZoom(in: geometry.size)
                            }
                            .accessibilityLabel("사진")
                            .accessibilityHint("두 번 탭하여 확대하거나 축소할 수 있습니다.")
                            .accessibilityAction(named: isCommittedPhotoZoomed ? "축소" : "확대") {
                                togglePhotoZoom(in: geometry.size)
                            }
                            .id(Self.photoScrollAnchor)

                            if isEditingInfo {
                                photoInfoEditView
                                    .frame(
                                        maxWidth: .infinity,
                                        minHeight: infoPanelMinHeight,
                                        alignment: .top
                                    )
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .scrollDisabled(!isEditingInfo)
                }
                .ignoresSafeArea()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                (isPhotoZoomed ? Color.black : Color.orange30)
                    .ignoresSafeArea()
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isPhotoZoomed)
            }
            .navigationBarBackButtonHidden(true)
            .overlay(alignment: .topLeading) {
                backButton {
                    setInfoEditing(false, scrollProxy: proxy)
                }
                .opacity(isPhotoZoomed ? 0 : 1)
                .allowsHitTesting(!isPhotoZoomed)
                .accessibilityHidden(isPhotoZoomed)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isPhotoZoomed)
            }
            .overlay(alignment: .bottom) {
                if !isEditingInfo {
                    actionBar
                        .opacity(isPhotoZoomed ? 0 : 1)
                        .allowsHitTesting(!isPhotoZoomed)
                        .accessibilityHidden(isPhotoZoomed)
                        .transition(.opacity)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isPhotoZoomed)
                }
            }
        }
        .statusBarHidden(isCommittedPhotoZoomed)
        .task(id: photo.localIdentifier) {
            await imageViewModel.loadImage(for: photo.localIdentifier)
        }
        .task(id: photo.localIdentifier) {
            guard !photo.localIdentifier.isEmpty else { return }
            didToggleFavorite = false
            let loaded = await loadIsFavorite(photo.localIdentifier)
            guard !didToggleFavorite else { return }
            isFavorite = loaded
        }
        .bottomSheet(isPresented: $showShareSheet, detents: [.full]) { dismiss in
            ShareSheet(
                albums: albums,
                sharedAlbums: Album.sharedSamples,
                shareAlbums: ShareAlbum.samples,
                onDismiss: { dismiss() },
                excludedAlbumIDs: excludedAlbumIDs,
                onComplete: { destinations in
                    guard !photo.localIdentifier.isEmpty else {
                        return
                    }

                    switch deletionContext {
                    case .album:
                        guard let albumPhotoID = photo.albumPhotoID else {
                            return
                        }
                        onMoveToAlbums([albumPhotoID], destinations)
                    case .gallery:
                        onAddToAlbums([photo.localIdentifier], destinations)
                    }
                    dismiss()
                }
            )
        }
        .bottomSheetAlert(
            isPresented: $showDeleteAlert,
            title: deleteAlertContent.title,
            message: deleteAlertContent.message,
            secondaryTitle: deleteAlertContent.secondaryTitle,
            primaryTitle: deleteAlertContent.primaryTitle,
            onSecondaryTap: handleSecondaryDeleteAction,
            onPrimaryTap: handlePrimaryDeleteAction
        )
    }

    private var deleteAlertContent: PhotoDeleteAlertContent {
        deletionContext.alertContent
    }

    private var isPhotoZoomed: Bool {
        clampedPhotoScale(photoScale * gestureScale) > Self.zoomActivationThreshold
    }

    private var isCommittedPhotoZoomed: Bool {
        photoScale > Self.zoomActivationThreshold
    }

    private var photoInfoEditView: some View {
        PhotoInfoEditContent(
            metadata: photo.metadata,
            localIdentifiers: photo.localIdentifier.isEmpty ? [] : [photo.localIdentifier],
            showsHeader: false,
            onLocalIdentifiersChange: updatePhotoIdentifier
        )
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.orange30)
    }

    private func backButton(onCloseInfo: @escaping () -> Void) -> some View {
        RoundedIconButton(items: [
            .init(id: "back", icon: .chevronLeft, accessibilityLabel: "뒤로가기") {
                if isEditingInfo {
                    onCloseInfo()
                } else {
                    dismiss()
                }
            }
        ])
        .opacity(0.9)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var actionBar: some View {
        ActionBar(items: [
            .init(
                icon: isFavorite ? .starFilled : .starStroke,
                title: "즐겨찾기",
                isDisabled: photo.localIdentifier.isEmpty
            ) { toggleFavorite() },
            .init(
                icon: .moveToAlbum,
                title: "집으로",
                isDisabled: photo.localIdentifier.isEmpty
            ) { showShareSheet = true },
            .init(icon: .metadata, title: "정보 수정") {
                setInfoEditing(true)
            },
            .init(icon: .delete, title: "삭제") { showDeleteAlert = true }
        ])
        .padding(.bottom, 16)
    }

    private func toggleFavorite() {
        guard !photo.localIdentifier.isEmpty else { return }

        didToggleFavorite = true
        let next = !isFavorite
        isFavorite = next
        onToggleFavorite(photo.localIdentifier, next)
    }

    private func setInfoEditing(_ isEditing: Bool) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.42, bounce: 0)) {
            if isEditing {
                resetPhotoTransform()
            }
            isEditingInfo = isEditing
        }
    }

    private func setInfoEditing(_ isEditing: Bool, scrollProxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.42, bounce: 0)) {
            scrollProxy.scrollTo(Self.photoScrollAnchor, anchor: .top)
            if isEditing {
                resetPhotoTransform()
            }
            isEditingInfo = isEditing
        }
    }

    private func photoGesture(in containerSize: CGSize) -> some Gesture {
        MagnifyGesture()
            .updating($gestureScale) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                let proposedScale = clampedPhotoScale(photoScale * value.magnification)
                let scale = proposedScale > Self.zoomActivationThreshold
                    ? proposedScale
                    : Self.minimumPhotoScale
                photoScale = scale
                photoOffset = clampedPhotoOffset(
                    photoOffset,
                    in: containerSize,
                    scale: scale
                )
            }
            .simultaneously(with: photoDragGesture(in: containerSize))
    }

    private func photoDragGesture(in containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($gestureOffset) { value, state, _ in
                guard photoScale * gestureScale > Self.zoomActivationThreshold else { return }
                state = value.translation
            }
            .onEnded { value in
                if photoScale * gestureScale > Self.zoomActivationThreshold {
                    photoOffset = clampedPhotoOffset(
                        adding: photoOffset,
                        and: value.translation,
                        in: containerSize,
                        scale: photoScale
                    )
                    return
                }

                let isVerticalSwipe = abs(value.translation.height) > abs(value.translation.width)
                let passedThreshold = value.translation.height < -Self.infoRevealThreshold
                    || value.predictedEndTranslation.height < -(Self.infoRevealThreshold * 1.5)

                if isVerticalSwipe, passedThreshold {
                    setInfoEditing(true)
                }
            }
    }

    private func togglePhotoZoom(in containerSize: CGSize) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.32, bounce: 0)) {
            if isCommittedPhotoZoomed {
                resetPhotoTransform()
            } else {
                photoScale = Self.doubleTapPhotoScale
                photoOffset = clampedPhotoOffset(
                    photoOffset,
                    in: containerSize,
                    scale: Self.doubleTapPhotoScale
                )
            }
        }
    }

    private func resetPhotoTransform() {
        photoScale = Self.minimumPhotoScale
        photoOffset = .zero
    }

    private func clampedPhotoScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, Self.minimumPhotoScale), Self.maximumPhotoScale)
    }

    private func clampedPhotoOffset(
        _ offset: CGSize,
        in containerSize: CGSize,
        scale: CGFloat
    ) -> CGSize {
        guard scale > Self.minimumPhotoScale else { return .zero }

        let scaledPhotoSize = aspectFitPhotoSize(in: containerSize, scale: scale)
        let maximumX = max((scaledPhotoSize.width - containerSize.width) / 2, 0)
        let maximumY = max((scaledPhotoSize.height - containerSize.height) / 2, 0)

        return CGSize(
            width: min(max(offset.width, -maximumX), maximumX),
            height: min(max(offset.height, -maximumY), maximumY)
        )
    }

    private func aspectFitPhotoSize(in containerSize: CGSize, scale: CGFloat) -> CGSize {
        guard imageViewModel.imageSize.width > 0,
              imageViewModel.imageSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0
        else {
            return containerSize
        }

        let fitScale = min(
            containerSize.width / imageViewModel.imageSize.width,
            containerSize.height / imageViewModel.imageSize.height
        )

        return CGSize(
            width: imageViewModel.imageSize.width * fitScale * scale,
            height: imageViewModel.imageSize.height * fitScale * scale
        )
    }

    private func clampedPhotoOffset(
        adding lhs: CGSize,
        and rhs: CGSize,
        in containerSize: CGSize,
        scale: CGFloat
    ) -> CGSize {
        clampedPhotoOffset(
            CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height),
            in: containerSize,
            scale: scale
        )
    }

    private func dismissDeleteAlert() {
        showDeleteAlert = false
    }

    private func handleSecondaryDeleteAction() {
        switch deletionContext {
        case .gallery:
            dismissDeleteAlert()
        case .album:
            completeDeletion(.deletePermanently)
        }
    }

    private func handlePrimaryDeleteAction() {
        switch deletionContext {
        case .gallery:
            completeDeletion(.deletePermanently)
        case .album:
            completeDeletion(.removeFromAlbum)
        }
    }

    private func completeDeletion(_ action: PhotoDeletionAction) {
        showDeleteAlert = false
        Task {
            if await onDelete(action, photo) {
                dismiss()
            }
        }
    }

    private func updatePhotoIdentifier(_ identifiers: [String]) {
        guard let newIdentifier = identifiers.first,
              newIdentifier != photo.localIdentifier
        else {
            return
        }
        photo = Photo(
            localIdentifier: newIdentifier,
            metadata: photo.metadata,
            albumPhotoID: photo.albumPhotoID
        )
    }
}

#Preview {
    PhotoDetailView(photo: PhotoSection.sample[0].photos[0])
}
