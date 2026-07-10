//
//  PhotoRecord.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import Foundation
import SQLiteData

@Table("photo")
struct PhotoRecord {
    let id: Int
    @Column("local_identifier") var localIdentifier: String
    @Column("content_hash") var contentHash: String?
    @Column("taken_at", as: Date.UnixTimeRepresentation?.self) var takenAt: Date?
    @Column("added_at", as: Date.UnixTimeRepresentation.self) var addedAt: Date
    @Column("is_favorite") var isFavorite = false
    var latitude: Double?
    var longitude: Double?
    var width: Int
    var height: Int
    @Column("device_id") var deviceID: Int?
    @Column("place_id") var placeID: Int?
}
