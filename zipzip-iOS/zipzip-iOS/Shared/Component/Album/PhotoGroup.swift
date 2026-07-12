//
//  PhotoGroup.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI
import UIKit

struct PhotoGroup: View {
    /// `nil` keeps the design-system placeholder used by previews.
    /// An empty array represents a real album without photos.
    var localIdentifiers: [String]? = nil
    @State private var thumbnailImages: [String: UIImage] = [:]

    private static let thumbnailSize = CGSize(width: 200, height: 160)

    var body: some View {
        ZStack {
            if let localIdentifiers {
                thumbnailItems(Array(localIdentifiers.prefix(3)))
            } else {
                placeholderItems
            }
        }
        .frame(width: 112, height: 96)
        .task(id: localIdentifiers) {
            await loadThumbnails()
        }
    }

    @ViewBuilder private func thumbnailItems(_ identifiers: [String]) -> some View {
        if identifiers.indices.contains(2) {
            PhotoKitPhotoItem(image: thumbnailImages[identifiers[2]])
                .frame(width: 100, height: 80)
        }
        if identifiers.indices.contains(1) {
            PhotoKitPhotoItem(image: thumbnailImages[identifiers[1]])
                .frame(width: 100, height: 80)
                .rotationEffect(.degrees(8))
        }
        if let newestIdentifier = identifiers.first {
            PhotoKitPhotoItem(image: thumbnailImages[newestIdentifier])
                .frame(width: 100, height: 80)
                .rotationEffect(.degrees(-10))
        }
    }

    @ViewBuilder private var placeholderItems: some View {
        PhotoItem()
            .frame(width: 100, height: 80)

        PhotoItem()
            .frame(width: 100, height: 80)
            .rotationEffect(.degrees(8))

        PhotoItem()
            .frame(width: 100, height: 80)
            .rotationEffect(.degrees(-10))
    }

    private func loadThumbnails() async {
        guard let localIdentifiers else {
            thumbnailImages = [:]
            return
        }

        thumbnailImages = [:]
        for localIdentifier in localIdentifiers.prefix(3) where !localIdentifier.isEmpty {
            guard let image = await PhotoThumbnailLoader.shared.thumbnail(
                for: localIdentifier,
                targetSize: Self.thumbnailSize
            ) else {
                continue
            }
            thumbnailImages[localIdentifier] = image
        }
    }
}

#Preview {
    PhotoGroup()
        .padding()
        .background(.grey50)
}
