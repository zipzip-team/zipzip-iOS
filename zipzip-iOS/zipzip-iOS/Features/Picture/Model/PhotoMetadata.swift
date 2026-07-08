//
//  PhotoMetadata.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import Foundation

struct PhotoMetadata: Hashable {
    let deviceName: String
    let deviceType: String
    let location: String
    let dateText: String
}

extension PhotoMetadata {
    /// 실제 데이터 연동 전까지 사용하는 더미 메타데이터.
    static let samples: [PhotoMetadata] = [
        PhotoMetadata(deviceName: "Canon IXUS 860", deviceType: "디지털 카메라", location: "오사카", dateText: "2026년 7월 2일"),
        PhotoMetadata(deviceName: "Sony Alpha a7 III", deviceType: "디지털 카메라", location: "교토", dateText: "2026년 7월 1일"),
        PhotoMetadata(deviceName: "iPhone 6", deviceType: "아이폰", location: "도쿄", dateText: "2026년 6월 30일"),
        PhotoMetadata(deviceName: "Fujifilm X100V", deviceType: "디지털 카메라", location: "후쿠오카", dateText: "2026년 6월 28일")
    ]
}
