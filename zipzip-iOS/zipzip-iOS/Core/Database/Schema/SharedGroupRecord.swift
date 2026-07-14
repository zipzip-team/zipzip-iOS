//
//  SharedGroupRecord.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import Foundation
import SQLiteData

@Table("shared_group")
struct SharedGroupRecord {
    let id: String
    @Column("created_by_user_id") var createdByUserID: String?
    @Column("created_by_display_name") var createdByDisplayName: String?
    var name: String
    @Column("invite_code") var inviteCode: String?
    @Column("created_at", as: Date.UnixTimeRepresentation?.self) var createdAt: Date?
    @Column("joined_at", as: Date.UnixTimeRepresentation?.self) var joinedAt: Date?
    @Column("updated_at", as: Date.UnixTimeRepresentation.self) var updatedAt: Date
    @Column("member_count") var memberCount: Int
    @Column("shared_album_count") var sharedAlbumCount: Int
    @Column("photo_count") var photoCount: Int
    @Column("my_role") var myRole: String
}
