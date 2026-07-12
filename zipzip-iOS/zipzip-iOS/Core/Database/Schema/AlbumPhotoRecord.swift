//
//  AlbumPhotoRecord.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import Foundation
import SQLiteData

@Table("album_photo")
struct AlbumPhotoRecord {
    let id: Int
    @Column("album_id") var albumID: Int
    @Column("photo_id") var photoID: Int
    @Column("added_at", as: Date.UnixTimeRepresentation.self) var addedAt: Date
}
