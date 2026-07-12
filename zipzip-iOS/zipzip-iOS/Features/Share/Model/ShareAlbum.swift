//
//  ShareAlbum.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import Foundation

struct ShareAlbum: Identifiable, Hashable {
    let id: UUID
    var name: String
    let date: Date
    let memberCount: Int
    var albums: [Album]

    init(
        id: UUID = UUID(),
        name: String,
        date: Date,
        memberCount: Int,
        albums: [Album] = []
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.memberCount = memberCount
        self.albums = albums
    }
}

extension ShareAlbum {
    /// 실제 데이터 연동 전까지 사용하는 더미 데이터.
    static let samples: [ShareAlbum] = [
        ShareAlbum(
            name: "집집팟",
            date: date(2026, 7, 2),
            memberCount: 4,
            albums: Album.sharedSamples
        ),
        ShareAlbum(
            name: "알콩달콩",
            date: date(2026, 7, 3),
            memberCount: 1,
            albums: Array(Album.sharedSamples.prefix(4))
        ),
        ShareAlbum(
            name: "하늘바람",
            date: date(2026, 7, 3),
            memberCount: 5,
            albums: Array(Album.sharedSamples.prefix(3))
        ),
        ShareAlbum(
            name: "달빛소리",
            date: date(2026, 7, 4),
            memberCount: 2,
            albums: Array(Album.sharedSamples.prefix(2))
        ),
        ShareAlbum(
            name: "별무리",
            date: date(2026, 7, 4),
            memberCount: 8,
            albums: Array(Album.sharedSamples.prefix(4))
        ),
        ShareAlbum(
            name: "꽃길만걷자",
            date: date(2026, 7, 5),
            memberCount: 3,
            albums: Array(Album.sharedSamples.prefix(3))
        )
    ]

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }
}

extension Album {
    /// 공유집에서 사용하는 앨범 더미 데이터. (사진집 앨범과 다른 세트)
    static let sharedSamples: [Album] = [
        Album(name: "여름 바다", count: 320),
        Album(name: "캠핑 기록", count: 88),
        Album(name: "주말 나들이", count: 512),
        Album(name: "생일 모음", count: 147),
        Album(name: "동네 한바퀴", count: 63)
    ]
}
