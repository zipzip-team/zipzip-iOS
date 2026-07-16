//
//  SharedPhotoRecord.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import Foundation
import SQLiteData

@Table("shared_photo")
struct SharedPhotoRecord {
    let id: String
    @Column("shared_group_id") var sharedGroupID: String
    @Column("local_photo_id") var localPhotoID: Int?
    @Column("original_url") var originalURL: String
    @Column("original_url_expires_at", as: Date.UnixTimeRepresentation.self) var originalURLExpiresAt: Date
    @Column("thumbnail_url") var thumbnailURL: String?
    @Column("thumbnail_url_expires_at", as: Date.UnixTimeRepresentation?.self) var thumbnailURLExpiresAt: Date?
    @Column("thumbnail_status") var thumbnailStatus: String
    @Column("device_model") var deviceModel: String?
    @Column("taken_at", as: Date.UnixTimeRepresentation?.self) var takenAt: Date?
    @Column("display_at", as: Date.UnixTimeRepresentation.self) var displayAt: Date
    var latitude: Double?
    var longitude: Double?
    @Column("location_name") var locationName: String?
    @Column("is_inferred") var isInferred: Bool
    var width: Int
    var height: Int
    @Column("uploaded_by_user_id") var uploadedByUserID: String?
    @Column("uploaded_by_display_name") var uploadedByDisplayName: String?
    @Column("is_uploader") var isUploader: Bool
    @Column("like_count") var likeCount: Int
    @Column("comment_count") var commentCount: Int
    @Column("is_liked_by_me") var isLikedByMe: Bool
    @Column("created_at", as: Date.UnixTimeRepresentation.self) var createdAt: Date
    @Column("updated_at", as: Date.UnixTimeRepresentation.self) var updatedAt: Date
}
