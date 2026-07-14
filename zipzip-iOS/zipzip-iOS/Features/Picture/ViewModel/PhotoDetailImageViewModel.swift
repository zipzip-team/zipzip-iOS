//
//  PhotoDetailImageViewModel.swift
//  zipzip-iOS
//

import Observation
import UIKit

@Observable
final class PhotoDetailImageViewModel {
    private static let previewSize = CGSize(width: 400, height: 400)
    private static let fullSize = CGSize(width: 1600, height: 1600)

    private(set) var image: UIImage?
    private(set) var imageSize: CGSize = .zero
    private(set) var isFullImageLoaded = false
    private(set) var loadFailed = false

    func loadImage(for localIdentifier: String) async {
        guard !localIdentifier.isEmpty else {
            image = nil
            imageSize = .zero
            isFullImageLoaded = false
            loadFailed = false
            return
        }

        image = nil
        imageSize = .zero
        loadFailed = false
        isFullImageLoaded = false

        let previewImage = await PhotoThumbnailLoader.shared.fastFullImage(
            for: localIdentifier,
            targetSize: Self.previewSize
        )
        guard !Task.isCancelled else { return }
        if let previewImage, !isFullImageLoaded {
            image = previewImage
            imageSize = previewImage.size
        }

        let fullImage = await PhotoThumbnailLoader.shared.fullImage(
            for: localIdentifier,
            targetSize: Self.fullSize
        )
        guard !Task.isCancelled else { return }

        if let fullImage {
            image = fullImage
            imageSize = fullImage.size
            isFullImageLoaded = true
        } else if image == nil {
            loadFailed = true
        }
    }
}
