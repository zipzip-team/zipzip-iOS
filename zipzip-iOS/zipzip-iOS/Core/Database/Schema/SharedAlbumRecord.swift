//
//  SharedAlbumRecord.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import SQLiteData

@Table("shared_album")
struct SharedAlbumRecord {
    let id: Int
    @Column("shared_group_id") var sharedGroupID: Int
    var name: String
}
