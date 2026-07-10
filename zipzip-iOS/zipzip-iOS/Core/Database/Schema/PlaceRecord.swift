//
//  PlaceRecord.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import SQLiteData

@Table("place")
struct PlaceRecord {
    let id: Int
    var name: String
    var latitude: Double
    var longitude: Double
}
