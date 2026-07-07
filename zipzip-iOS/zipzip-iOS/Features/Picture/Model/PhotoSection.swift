//
//  PhotoSection.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/7/26.
//

import Foundation

struct PhotoSection: Identifiable {
    let id = UUID()
    let title: String
    let count: Int
}

extension PhotoSection {
    /// 실제 데이터 연동 전까지 사용하는 더미 데이터.
    static let sample: [PhotoSection] = [
        PhotoSection(title: "오늘", count: 8),
        PhotoSection(title: "어제", count: 8),
        PhotoSection(title: "7월 1일", count: 8),
        PhotoSection(title: "6월 30일", count: 8)
    ]
}
