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
    let addedDate: Date
    let latitude: Double?
    let longitude: Double?
    let width: Int
    let height: Int
    let isFavorite: Bool
    let make: String?
    let model: String?

    private init(asset: PHAsset, make: String?, model: String?) {
        self.localIdentifier = asset.localIdentifier
        self.creationDate = asset.creationDate
        self.addedDate = asset.addedDate
        self.latitude = asset.location?.coordinate.latitude
        self.longitude = asset.location?.coordinate.longitude
        self.width = asset.pixelWidth
        self.height = asset.pixelHeight
        self.isFavorite = asset.isFavorite
        self.make = make
        self.model = model
    }

    /// PHAsset의 기본 메타데이터에 원본 EXIF 촬영 기기 정보(make/model)를 더해 생성한다.
    static func load(from asset: PHAsset) async -> AssetMetadata {
        let (make, model) = await AssetEXIFReader.deviceInfo(for: asset)
        return AssetMetadata(asset: asset, make: make, model: model)
    }
}
