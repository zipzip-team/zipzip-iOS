//
//  AssetMetadata.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import Foundation
import Photos

nonisolated struct AssetMetadata {
    let localIdentifier: String
    let creationDate: Date?
    let latitude: Double?
    let longitude: Double?
    let width: Int
    let height: Int
    let isFavorite: Bool

    init(asset: PHAsset) {
        self.localIdentifier = asset.localIdentifier
        self.creationDate = asset.creationDate
        self.latitude = asset.location?.coordinate.latitude
        self.longitude = asset.location?.coordinate.longitude
        self.width = asset.pixelWidth
        self.height = asset.pixelHeight
        self.isFavorite = asset.isFavorite
    }
}
