//
//  PhotoSection.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/7/26.
//

import Foundation

struct Photo: Identifiable, Hashable {
    let id = UUID()
    let localIdentifier: String
    let metadata: PhotoMetadata

    init(localIdentifier: String = "", metadata: PhotoMetadata) {
        self.localIdentifier = localIdentifier
        self.metadata = metadata
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
