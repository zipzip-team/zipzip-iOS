//
//  SharedPhotoUploadTaskRecord.swift
//  zipzip-iOS
//

import Foundation
import SQLiteData

@Table("shared_photo_upload_task")
struct SharedPhotoUploadTaskRecord {
    let id: String
    @Column("batch_id") var batchID: String
    @Column("shared_group_id") var sharedGroupID: String
    @Column("shared_album_id") var sharedAlbumID: String
    @Column("local_photo_id") var localPhotoID: Int
    @Column("object_key") var objectKey: String
    @Column("upload_url") var uploadURL: String
    @Column("upload_url_expires_at", as: Date.UnixTimeRepresentation.self) var uploadURLExpiresAt: Date
    @Column("content_type") var contentType: String
    @Column("size_bytes") var sizeBytes: Int
    @Column("idempotency_key") var idempotencyKey: String
    var status: String
    @Column("created_at", as: Date.UnixTimeRepresentation.self) var createdAt: Date
}
