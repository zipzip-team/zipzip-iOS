//
//  SharedAlbumRecord.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import Foundation
import SQLiteData

@Table("shared_album")
struct SharedAlbumRecord {
    let id: String
    @Column("shared_group_id") var sharedGroupID: String
    var name: String
    @Column("photo_count") var photoCount: Int
    @Column("created_by_user_id") var createdByUserID: String?
    @Column("created_by_display_name") var createdByDisplayName: String?
    @Column("is_creator") var isCreator: Bool
    @Column("created_at", as: Date.UnixTimeRepresentation.self) var createdAt: Date
    @Column("updated_at", as: Date.UnixTimeRepresentation.self) var updatedAt: Date
}
