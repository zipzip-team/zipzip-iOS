//
//  PhotoDeletionService.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/12/26.
//

import Photos
import SQLiteData

nonisolated struct PhotoDeletionService {
    @Dependency(\.defaultDatabase) private var database

    func delete(localIdentifiers: [String]) async throws {
        guard !localIdentifiers.isEmpty else { return }
        try await deleteAssets(localIdentifiers)
        try await database.write { db in
            try PhotoRecord
                .delete()
                .where { $0.localIdentifier.in(localIdentifiers) }
                .execute(db)
        }
    }

    private func deleteAssets(_ localIdentifiers: [String]) async throws {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        guard assets.firstObject != nil else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }
}

private enum PhotoDeletionServiceKey: DependencyKey {
    static let liveValue = PhotoDeletionService()
}

extension DependencyValues {
    var photoDeletion: PhotoDeletionService {
        get { self[PhotoDeletionServiceKey.self] }
        set { self[PhotoDeletionServiceKey.self] = newValue }
    }
}
