//
//  Album.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import Foundation

struct Album: Identifiable, Hashable {
    let id: Int
    let name: String
    let count: Int
}

extension Album {
    /// 사진집(개인) 앨범 더미 데이터.
    static let samples: [Album] = [
        Album(id: 1, name: "우리 가족", count: 678),
        Album(id: 2, name: "집집 🏠", count: 234),
        Album(id: 3, name: "도쿄 여행 🍥", count: 456),
        Album(id: 4, name: "솝트", count: 1234),
        Album(id: 5, name: "호미 🐶", count: 45)
    ]
}
