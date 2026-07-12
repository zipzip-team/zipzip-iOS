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
    let devicePending: Bool

    private init(asset: PHAsset, make: String?, model: String?, devicePending: Bool) {
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
        self.devicePending = devicePending
    }

    /// 임포트 단계에서는 로컬 원본만 읽는다. iCloud 전용 사진은 devicePending으로 표시해 백필로 미룬다.
    static func load(from asset: PHAsset) async -> AssetMetadata {
        switch await AssetEXIFReader.deviceInfo(for: asset, allowsNetwork: false) {
        case let .resolved(make, model):
            return AssetMetadata(asset: asset, make: make, model: model, devicePending: false)
        case .pending:
            return AssetMetadata(asset: asset, make: nil, model: nil, devicePending: true)
        }
    }
}
