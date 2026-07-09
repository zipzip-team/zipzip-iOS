//
//  PhotoDetailView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct PhotoDetailView: View {
    enum DeletionContext {
        case gallery
        case album
    }

    @Environment(\.dismiss) private var dismiss

    let photo: Photo
    let deletionContext: DeletionContext

    @State private var isEditingInfo = false
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var isFavorite = false

    private let photoPeekHeight: CGFloat = 160

    init(photo: Photo, deletionContext: DeletionContext = .gallery) {
        self.photo = photo
        self.deletionContext = deletionContext
    }

    var body: some View {
        GeometryReader { geo in
            let reveal = max(geo.size.height - photoPeekHeight, 0)

            VStack(spacing: 0) {
                Color.grey200
                    .frame(width: geo.size.width, height: geo.size.height)

                ScrollView {
                    PhotoInfoEditContent(metadata: photo.metadata)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: geo.size.width, height: reveal)
            }
            .offset(y: isEditingInfo ? -reveal : 0)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .clipped()
            .animation(.easeInOut(duration: 0.3), value: isEditingInfo)
        }
        .background(Color.orange30.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .topLeading) {
            backButton
        }
        .overlay(alignment: .bottom) {
            if !isEditingInfo {
                actionBar.transition(.opacity)
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
            onSecondaryTap: dismissDeleteAlert,
            onPrimaryTap: dismissDeleteAlert
        )
    }

    private var deleteAlertContent: (
        title: String,
        message: String,
        secondaryTitle: String,
        primaryTitle: String
    ) {
        switch deletionContext {
        case .gallery:
            return (
                title: "이 사진을 삭제하시겠어요?",
                message: "삭제하면 집집과 사진 앱에서 모두 사라져요.",
                secondaryTitle: "취소",
                primaryTitle: "삭제"
            )
        case .album:
            return (
                title: "사진을 완전히 삭제할까요,\n아니면 사진집에서만 제거할까요?",
                message: "사진집에서 제거된 사진은 갤러리에 남아있어요",
                secondaryTitle: "삭제",
                primaryTitle: "사진집에서 제거"
            )
        }
    }

    private var backButton: some View {
        RoundedIconButton(items: [
            .init(id: "back", icon: .chevronLeft) {
                if isEditingInfo {
                    withAnimation { isEditingInfo = false }
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
                withAnimation { isEditingInfo = true }
            },
            .init(icon: .delete, title: "삭제") { showDeleteAlert = true }
        ])
        .padding(.bottom, 16)
    }

    private func dismissDeleteAlert() {
        showDeleteAlert = false
    }
}

#Preview {
    PhotoDetailView(photo: PhotoSection.sample[0].photos[0])
}
