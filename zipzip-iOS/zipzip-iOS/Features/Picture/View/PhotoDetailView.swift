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

    let photo: Photo
    let deletionContext: PhotoDeletionContext
    private let onDelete: (PhotoDeletionAction) -> Void

    @State private var isEditingInfo = false
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var isFavorite = false
    @State private var photoScale: CGFloat = 1
    @State private var photoOffset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureOffset: CGSize = .zero

    private static let photoScrollAnchor = "photo-detail-image"
    private static let minimumPhotoScale: CGFloat = 1
    private static let maximumPhotoScale: CGFloat = 4
    private static let doubleTapPhotoScale: CGFloat = 2
    private static let infoRevealThreshold: CGFloat = 72

    init(
        photo: Photo,
        deletionContext: PhotoDeletionContext = .gallery,
        onDelete: @escaping (PhotoDeletionAction) -> Void = { _ in }
    ) {
        self.photo = photo
        self.deletionContext = deletionContext
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollViewReader { proxy in
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
                            localIdentifier: photo.localIdentifier,
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
                        .accessibilityAction(named: photoScale > Self.minimumPhotoScale ? "축소" : "확대") {
                            togglePhotoZoom(in: geometry.size)
                        }
                        .id(Self.photoScrollAnchor)

                        photoInfoEditView
                            .frame(
                                maxWidth: .infinity,
                                minHeight: infoPanelMinHeight,
                                alignment: .top
                            )
                            .allowsHitTesting(isEditingInfo)
                            .accessibilityHidden(!isEditingInfo)
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollDisabled(!isEditingInfo)
                .ignoresSafeArea(.container, edges: .top)
            }

            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.orange30.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .overlay(alignment: .topLeading) {
                backButton {
                    setInfoEditing(false, scrollProxy: proxy)
                }
            }
            .overlay(alignment: .bottom) {
                if !isEditingInfo {
                    actionBar.transition(.opacity)
                }
            }
        }
        .bottomSheet(isPresented: $showShareSheet, detents: [.full]) { dismiss in
            ShareSheet(
                albums: Album.samples,
                sharedAlbums: Album.sharedSamples,
                shareAlbums: ShareAlbum.samples,
                onDismiss: { dismiss() }
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

    private var photoInfoEditView: some View {
        PhotoInfoEditContent(
            metadata: photo.metadata,
            showsHeader: false
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
            .init(icon: isFavorite ? .starFilled : .starStroke, title: "즐겨찾기") { isFavorite.toggle() },
            .init(icon: .moveToAlbum, title: "집으로") { showShareSheet = true },
            .init(icon: .metadata, title: "정보 수정") {
                setInfoEditing(true)
            },
            .init(icon: .delete, title: "삭제") { showDeleteAlert = true }
        ])
        .padding(.bottom, 16)
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
                let scale = clampedPhotoScale(photoScale * value.magnification)
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
                guard photoScale * gestureScale > Self.minimumPhotoScale else { return }
                state = value.translation
            }
            .onEnded { value in
                if photoScale * gestureScale > Self.minimumPhotoScale {
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
            if photoScale > Self.minimumPhotoScale {
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

        let maximumX = containerSize.width * (scale - Self.minimumPhotoScale) / 2
        let maximumY = containerSize.height * (scale - Self.minimumPhotoScale) / 2

        return CGSize(
            width: min(max(offset.width, -maximumX), maximumX),
            height: min(max(offset.height, -maximumY), maximumY)
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
        onDelete(action)
        dismiss()
    }
}

#Preview {
    PhotoDetailView(photo: PhotoSection.sample[0].photos[0])
}
