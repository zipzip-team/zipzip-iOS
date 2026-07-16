//
//  SharedAlbumPhoto.swift
//  zipzip-iOS
//

import Foundation

enum SharedAlbumPhotoThumbnailStatus: String, Hashable {
    case pending = "PENDING"
    case ready = "READY"
    case failed = "FAILED"
    case unknown

    init(serverValue: String) {
        self = Self(rawValue: serverValue.uppercased()) ?? .unknown
    }
}

/// 공유집 상세 화면에 로컬 DB에서 전달하는 사진 모델.
struct SharedAlbumPhoto: Identifiable, Hashable {
    let id: UUID
    let localIdentifier: String?
    let originalURL: URL?
    let originalURLExpiresAt: Date?
    let thumbnailURL: URL?
    let thumbnailURLExpiresAt: Date?
    let thumbnailStatus: SharedAlbumPhotoThumbnailStatus
    let displayAt: Date

    init(
        id: UUID,
        localIdentifier: String? = nil,
        originalURL: URL? = nil,
        originalURLExpiresAt: Date? = nil,
        thumbnailURL: URL? = nil,
        thumbnailURLExpiresAt: Date? = nil,
        thumbnailStatus: SharedAlbumPhotoThumbnailStatus = .pending,
        displayAt: Date
    ) {
        self.id = id
        self.localIdentifier = localIdentifier
        self.originalURL = originalURL
        self.originalURLExpiresAt = originalURLExpiresAt
        self.thumbnailURL = thumbnailURL
        self.thumbnailURLExpiresAt = thumbnailURLExpiresAt
        self.thumbnailStatus = thumbnailStatus
        self.displayAt = displayAt
    }

    var hasLocalCopy: Bool {
        guard let localIdentifier else { return false }
        return !localIdentifier.isEmpty
    }

    func validOriginalURL(at date: Date = .now) -> URL? {
        guard let originalURL,
              let originalURLExpiresAt,
              originalURLExpiresAt > date
        else {
            return nil
        }
        return originalURL
    }

    func validThumbnailURL(at date: Date = .now) -> URL? {
        guard let thumbnailURL,
              let thumbnailURLExpiresAt,
              thumbnailURLExpiresAt > date
        else {
            return nil
        }
        return thumbnailURL
    }

    func hasExpiredRemoteURL(at date: Date = .now) -> Bool {
        if thumbnailURL != nil, thumbnailURLExpiresAt.map({ $0 <= date }) ?? true {
            return true
        }
        if originalURL != nil, originalURLExpiresAt.map({ $0 <= date }) ?? true {
            return true
        }
        return false
    }
}

struct SharedAlbumPhotoSection: Identifiable, Hashable {
    let id: Date
    let title: String
    let photos: [SharedAlbumPhoto]
}

struct SharedAlbumPhotoMutationResult: Equatable {
    let succeededCount: Int
    let failedCount: Int
    let succeededLocalIdentifiers: [String]

    init(
        succeededCount: Int,
        failedCount: Int = 0,
        succeededLocalIdentifiers: [String] = []
    ) {
        self.succeededCount = succeededCount
        self.failedCount = failedCount
        self.succeededLocalIdentifiers = succeededLocalIdentifiers
    }
}
