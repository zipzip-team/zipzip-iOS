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

    private static let photoScrollAnchor = "photo-detail-image"

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
                        .clipped()
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
            isEditingInfo = isEditing
        }
    }

    private func setInfoEditing(_ isEditing: Bool, scrollProxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.42, bounce: 0)) {
            scrollProxy.scrollTo(Self.photoScrollAnchor, anchor: .top)
            isEditingInfo = isEditing
        }
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
