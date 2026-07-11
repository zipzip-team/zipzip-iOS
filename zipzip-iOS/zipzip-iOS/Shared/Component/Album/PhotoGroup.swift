//
//  PhotoGroup.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct PhotoGroup: View {
    /// `nil` keeps the design-system placeholder used by previews.
    /// An empty array represents a real album without photos.
    var localIdentifiers: [String]? = nil

    var body: some View {
        ZStack {
            if let localIdentifiers {
                thumbnailItems(Array(localIdentifiers.prefix(3)))
            } else {
                placeholderItems
            }
        }
        .frame(width: 112, height: 96)
    }

    @ViewBuilder private func thumbnailItems(_ identifiers: [String]) -> some View {
        if identifiers.indices.contains(2) {
            PhotoKitPhotoItem(localIdentifier: identifiers[2])
                .frame(width: 100, height: 80)
        }
        if identifiers.indices.contains(1) {
            PhotoKitPhotoItem(localIdentifier: identifiers[1])
                .frame(width: 100, height: 80)
                .rotationEffect(.degrees(8))
        }
        if let newestIdentifier = identifiers.first {
            PhotoKitPhotoItem(localIdentifier: newestIdentifier)
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
}

#Preview {
    PhotoGroup()
        .padding()
        .background(.grey50)
}
