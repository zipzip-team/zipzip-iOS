//
//  PhotoDetailImage.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import SwiftUI
import UIKit

struct PhotoDetailImage: View {
    let localIdentifier: String
    let contentMode: ContentMode

    @State private var image: UIImage?

    private static let targetSize = CGSize(width: 1600, height: 1600)

    init(localIdentifier: String, contentMode: ContentMode = .fit) {
        self.localIdentifier = localIdentifier
        self.contentMode = contentMode
    }

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                }
            }
            .task(id: localIdentifier) {
                guard !localIdentifier.isEmpty else { return }
                image = await PhotoThumbnailLoader.shared.fullImage(
                    for: localIdentifier,
                    targetSize: Self.targetSize
                )
            }
    }
}
