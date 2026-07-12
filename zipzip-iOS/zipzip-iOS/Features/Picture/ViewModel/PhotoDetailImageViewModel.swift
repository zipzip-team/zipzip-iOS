//
//  PhotoDetailImageViewModel.swift
//  zipzip-iOS
//

import Observation
import UIKit

@Observable
final class PhotoDetailImageViewModel {
    private static let targetSize = CGSize(width: 1600, height: 1600)

    private(set) var image: UIImage?
    private(set) var imageSize: CGSize = .zero

    func loadImage(for localIdentifier: String) async {
        guard !localIdentifier.isEmpty else {
            image = nil
            imageSize = .zero
            return
        }

        let loadedImage = await PhotoThumbnailLoader.shared.fullImage(
            for: localIdentifier,
            targetSize: Self.targetSize
        )
        guard !Task.isCancelled else { return }

        image = loadedImage
        imageSize = loadedImage?.size ?? .zero
    }
}
