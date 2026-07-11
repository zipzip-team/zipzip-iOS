//
//  PhotoItem.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import Photos
import SwiftUI
import UIKit

struct PhotoItem: View {
    private let cornerRadius: CGFloat = 4

    let image: Image?

    init(image: Image? = nil) {
        self.image = image
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.grey500)
            .overlay {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white00, lineWidth: 2)
            }
    }
}

struct PhotoKitPhotoItem: View {
    let localIdentifier: String

    @State private var image: UIImage?

    var body: some View {
        PhotoItem(image: image.map(Image.init(uiImage:)))
            .task(id: localIdentifier) {
                image = await requestImage()
            }
    }

    private func requestImage() async -> UIImage? {
        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: [localIdentifier],
            options: nil
        )
        guard let asset = result.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            PHCachingImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 200, height: 160),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        PhotoItem()
        PhotoItem(image: Image(systemName: "photo"))
    }
    .frame(height: 80)
    .padding()
    .background(.grey200)
}
