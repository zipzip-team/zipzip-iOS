//
//  PhotoThumbnail.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import SwiftUI
import UIKit

struct PhotoThumbnail: View {
    let localIdentifier: String

    @State private var image: UIImage?

    private static let targetSize = CGSize(width: 300, height: 300)

    var body: some View {
        Color.grey200
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .task(id: localIdentifier) {
                guard !localIdentifier.isEmpty else { return }
                image = await PhotoThumbnailLoader.shared.thumbnail(
                    for: localIdentifier,
                    targetSize: Self.targetSize
                )
            }
    }
}
