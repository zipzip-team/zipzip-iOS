//
//  ShareAlbum.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import Foundation

enum ShareGroupRole: String, Hashable {
    case admin = "HOST"
    case participant = "MEMBER"
}

struct ShareGroupUser: Hashable {
    let id: UUID?
    let displayName: String?
}

/// 공유 그룹 화면에서 사용하는 그룹 모델.
struct ShareAlbum: Identifiable, Hashable {
    let id: UUID
    var name: String
    var date: Date
    var memberCount: Int
    var currentUserRole: ShareGroupRole
    var albums: [SharedAlbum]
    var sharedAlbumCount: Int
    var photoCount: Int
    var representativeImageURL: URL?
    var representativeImageURLExpiresAt: Date?
    var createdBy: ShareGroupUser?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        date: Date,
        memberCount: Int,
        currentUserRole: ShareGroupRole = .admin,
        albums: [SharedAlbum] = [],
        sharedAlbumCount: Int = 0,
        photoCount: Int = 0,
        representativeImageURL: URL? = nil,
        representativeImageURLExpiresAt: Date? = nil,
        createdBy: ShareGroupUser? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.memberCount = memberCount
        self.currentUserRole = currentUserRole
        self.albums = albums
        self.sharedAlbumCount = sharedAlbumCount
        self.photoCount = photoCount
        self.representativeImageURL = representativeImageURL
        self.representativeImageURLExpiresAt = representativeImageURLExpiresAt
        self.createdBy = createdBy
        self.updatedAt = updatedAt ?? date
    }

    func validRepresentativeImageURL(at date: Date = .now) -> URL? {
        guard let representativeImageURL else { return nil }
        if let representativeImageURLExpiresAt,
           representativeImageURLExpiresAt <= date {
            return nil
        }
        return representativeImageURL
    }

    func hasExpiredRepresentativeImage(at date: Date = .now) -> Bool {
        guard representativeImageURL != nil,
              let representativeImageURLExpiresAt
        else {
            return false
        }
        return representativeImageURLExpiresAt <= date
    }
}

struct SharedAlbum: Identifiable, Hashable {
    let id: UUID
    let sharedGroupID: UUID
    var name: String
    var count: Int
    var thumbnails: [SharedAlbumThumbnail] = []
    let createdBy: ShareGroupUser?
    let isCreator: Bool
    let createdAt: Date
    var updatedAt: Date

    func validThumbnailURLs(at date: Date = .now) -> [URL] {
        thumbnails.compactMap { $0.urlExpiresAt > date ? $0.url : nil }
    }
}

struct SharedAlbumThumbnail: Hashable {
    let url: URL
    let urlExpiresAt: Date
}
