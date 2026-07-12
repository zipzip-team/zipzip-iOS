//
//  DeviceRecord.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import SQLiteData

@Table("device")
struct DeviceRecord {
    let id: Int
    var make: String?
    var model: String?
    @Column("is_registered") var isRegistered = false
}
