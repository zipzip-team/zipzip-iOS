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
    let id: Int
    @Column("created_by_user_id") var createdByUserID: Int?
    var name: String
    @Column("invite_code") var inviteCode: String?
    @Column("created_at", as: Date.UnixTimeRepresentation?.self) var createdAt: Date?
}
