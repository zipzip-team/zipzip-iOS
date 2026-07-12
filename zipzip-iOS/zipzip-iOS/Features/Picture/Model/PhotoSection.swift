//
//  PhotoSection.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/7/26.
//

import CryptoKit
import Foundation

struct Photo: Identifiable, Hashable {
    let id: UUID
    let localIdentifier: String
    let metadata: PhotoMetadata
    let albumPhotoID: Int?

    init(
        localIdentifier: String = "",
        metadata: PhotoMetadata,
        albumPhotoID: Int? = nil
    ) {
        self.localIdentifier = localIdentifier
        self.metadata = metadata
        self.albumPhotoID = albumPhotoID
        if let albumPhotoID {
            self.id = Self.stableID(for: "album-photo-\(albumPhotoID)")
        } else {
            self.id = localIdentifier.isEmpty ? UUID() : Self.stableID(for: localIdentifier)
        }
    }

    private static func stableID(for localIdentifier: String) -> UUID {
        let bytes = Array(Insecure.MD5.hash(data: Data(localIdentifier.utf8)))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

extension Photo {
    static func make(_ count: Int) -> [Photo] {
        (0 ..< count).map { index in
            Photo(metadata: PhotoMetadata.samples[index % PhotoMetadata.samples.count])
        }
    }
}

struct PhotoSection: Identifiable {
    let id = UUID()
    let title: String
    let photos: [Photo]
}

extension PhotoSection {
    /// 실제 데이터 연동 전까지 사용하는 더미 데이터.
    static let sample: [PhotoSection] = [
        PhotoSection(title: "오늘", photos: Photo.make(8)),
        PhotoSection(title: "어제", photos: Photo.make(8)),
        PhotoSection(title: "7월 1일", photos: Photo.make(8)),
        PhotoSection(title: "6월 30일", photos: Photo.make(8))
    ]
}

extension Array where Element == PhotoSection {
    func localIdentifiers(for photoIDs: [UUID]) -> [String] {
        let photosByID = Dictionary(uniqueKeysWithValues: flatMap(\.photos).map { ($0.id, $0) })
        return photoIDs.compactMap { photoID in
            guard let localIdentifier = photosByID[photoID]?.localIdentifier,
                  !localIdentifier.isEmpty
            else {
                return nil
            }
            return localIdentifier
        }
    }
}
