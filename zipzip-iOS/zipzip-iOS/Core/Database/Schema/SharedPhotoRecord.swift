//
//  SharedPhotoRecord.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import SQLiteData

@Table("shared_photo")
struct SharedPhotoRecord {
    let id: String
    @Column("shared_album_id") var sharedAlbumID: String
    @Column("content_hash") var contentHash: String?
    @Column("original_file_name") var originalFileName: String?
}
