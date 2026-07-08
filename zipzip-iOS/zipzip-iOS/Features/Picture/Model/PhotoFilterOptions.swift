//
//  PhotoFilterOptions.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/7/26.
//

import Foundation

struct FilterDevice: Hashable {
    let name: String
    let type: String
}

enum FilterKind: Hashable {
    case device
    case location
    case date
    case etc
}

struct AppliedFilter: Hashable {
    let kind: FilterKind
    let value: String
}

struct PhotoFilterOptions {
    let devices: [FilterDevice]
    let locations: [String]
    let etcItems: [String]
    let dateText: String
}

extension PhotoFilterOptions {
    /// 실제 데이터 연동 전까지 사용하는 더미 데이터.
    static let sample = PhotoFilterOptions(
        devices: [
            FilterDevice(name: "Canon IXUS 860", type: "디지털 카메라"),
            FilterDevice(name: "Sony Alpha a7 III", type: "디지털 카메라"),
            FilterDevice(name: "Iphone 6", type: "아이폰")
        ],
        locations: ["오사카", "교토", "도쿄", "후쿠오카", "삿포로", "히로시마"],
        etcItems: ["최근 저장된 사진", "장소 정보 없음", "날짜 정보 없음"],
        dateText: "2026년 7월 2일"
    )
}
