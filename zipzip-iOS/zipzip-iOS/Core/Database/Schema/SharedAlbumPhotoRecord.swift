//
//  SharedAlbumPhotoRecord.swift
//  zipzip-iOS
//

import Foundation
import SQLiteData

@Table("shared_album_photo")
struct SharedAlbumPhotoRecord {
    @Column("shared_album_id") var sharedAlbumID: String
    @Column("shared_photo_id") var sharedPhotoID: String
    @Column("display_at", as: Date.UnixTimeRepresentation.self) var displayAt: Date
}
