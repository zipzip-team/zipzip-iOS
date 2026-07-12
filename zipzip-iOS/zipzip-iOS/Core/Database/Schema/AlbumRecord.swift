//
//  AlbumRecord.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import Foundation
import SQLiteData

@Table("album")
struct AlbumRecord {
    let id: Int
    var name: String
    @Column("created_at", as: Date.UnixTimeRepresentation.self) var createdAt: Date
    @Column("is_favorite") var isFavorite = false
}
