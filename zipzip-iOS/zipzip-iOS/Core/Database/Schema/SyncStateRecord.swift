//
//  SyncStateRecord.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import SQLiteData

@Table("sync_state")
struct SyncStateRecord {
    let id: Int
    @Column("change_token") var changeToken: String?
}
