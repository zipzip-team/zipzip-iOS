//
//  Album.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import Foundation

struct Album: Identifiable, Hashable {
    let id: UUID
    let name: String
    let count: Int

    init(id: UUID = UUID(), name: String, count: Int) {
        self.id = id
        self.name = name
        self.count = count
    }
}

extension Album {
    /// 사진집(개인) 앨범 더미 데이터.
    static let samples: [Album] = [
        Album(name: "우리 가족", count: 678),
        Album(name: "집집 🏠", count: 234),
        Album(name: "도쿄 여행 🍥", count: 456),
        Album(name: "솝트", count: 1234),
        Album(name: "호미 🐶", count: 45)
    ]
}
