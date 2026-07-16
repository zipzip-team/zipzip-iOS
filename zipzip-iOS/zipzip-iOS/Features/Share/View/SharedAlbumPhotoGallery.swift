//
//  SharedAlbumPhotoGallery.swift
//  zipzip-iOS
//

import SwiftUI
import UIKit

struct SharedAlbumPhotoGallery: View {
    let sections: [SharedAlbumPhotoSection]
    var isSelectionMode = false
    var selectedPhotoIDs: [SharedAlbumPhoto.ID] = []
    var onSelectPhoto: (SharedAlbumPhoto.ID) -> Void = { _ in }
    var onBeginSelection: (SharedAlbumPhoto.ID) -> Void = { _ in }
    var onNeedsURLRefresh: () async -> Void = {}

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 4
    )

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.b2_sb)
                        .foregroundStyle(.grey1000)

                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(section.photos) { photo in
                            photoCell(photo)
                        }
                    }
                }
            }
        }
    }

    private func photoCell(_ photo: SharedAlbumPhoto) -> some View {
        SharedAlbumPhotoThumbnail(
            photo: photo,
            onNeedsURLRefresh: onNeedsURLRefresh
        )
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            if isSelectionMode, selectedPhotoIDs.contains(photo.id) {
                Rectangle()
                    .strokeBorder(.orange500, lineWidth: 2)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isSelectionMode {
                Indicator(
                    title: selectedPhotoIDs.firstIndex(of: photo.id).map { "\($0 + 1)" },
                    status: selectedPhotoIDs.contains(photo.id) ? .selected : .default
                )
                .padding(6)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            guard isSelectionMode else { return }
            onSelectPhoto(photo.id)
        }
        .onLongPressGesture {
            onBeginSelection(photo.id)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("공유 사진")
        .accessibilityValue(accessibilityValue(for: photo.id))
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(
            isSelectionMode && selectedPhotoIDs.contains(photo.id) ? .isSelected : []
        )
        .accessibilityAction {
            if isSelectionMode {
                onSelectPhoto(photo.id)
            }
        }
    }

    private func accessibilityValue(for photoID: SharedAlbumPhoto.ID) -> String {
        guard isSelectionMode else { return "" }
        if let index = selectedPhotoIDs.firstIndex(of: photoID) {
            return "\(index + 1)번째 선택됨"
        }
        return "선택 안 됨"
    }
}

private struct SharedAlbumPhotoThumbnail: View {
    let photo: SharedAlbumPhoto
    let onNeedsURLRefresh: () async -> Void

    @State private var localImage: UIImage?
    @State private var didAttemptLocalLoad = false

    private static let targetSize = CGSize(width: 300, height: 300)

    var body: some View {
        Color.grey200
            .overlay {
                thumbnailContent
            }
            .clipped()
            .task(id: photo.localIdentifier) {
                await loadLocalThumbnail()
            }
            .task(id: photo) {
                guard !photo.hasLocalCopy, photo.hasExpiredRemoteURL() else { return }
                await onNeedsURLRefresh()
            }
    }

    @ViewBuilder private var thumbnailContent: some View {
        if let localImage {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        } else if photo.hasLocalCopy, !didAttemptLocalLoad {
            ProgressView()
                .tint(.grey500)
        } else if photo.thumbnailStatus == .pending {
            ProgressView()
                .tint(.grey500)
                .accessibilityLabel("썸네일 처리 중")
        } else if let remoteURL {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                        .accessibilityHidden(true)
                default:
                    Color.grey200
                }
            }
        }
    }

    private var remoteURL: URL? {
        switch photo.thumbnailStatus {
        case .ready:
            photo.validThumbnailURL()
        case .failed, .unknown:
            photo.validOriginalURL()
        case .pending:
            nil
        }
    }

    private func loadLocalThumbnail() async {
        localImage = nil
        didAttemptLocalLoad = false
        guard let localIdentifier = photo.localIdentifier,
              !localIdentifier.isEmpty
        else {
            didAttemptLocalLoad = true
            return
        }

        let image = await PhotoThumbnailLoader.shared.thumbnail(
            for: localIdentifier,
            targetSize: Self.targetSize
        )
        guard !Task.isCancelled else { return }
        localImage = image
        didAttemptLocalLoad = true
    }
}
