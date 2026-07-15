//
//  SharedCacheOwnerRecord.swift
//  zipzip-iOS
//

import SQLiteData

@Table("shared_cache_owner")
struct SharedCacheOwnerRecord {
    let id: Int
    @Column("user_id") var userID: String
}
