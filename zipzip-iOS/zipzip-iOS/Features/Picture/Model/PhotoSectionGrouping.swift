//
//  PhotoSectionGrouping.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import Foundation

enum PhotoSectionGrouping {
    static func sections(from items: [(date: Date?, photo: Photo)]) -> [PhotoSection] {
        let calendar = Calendar.current

        var order: [Date?] = []
        var groups: [Date?: [Photo]] = [:]

        for (date, photo) in items {
            let key = date.map { calendar.startOfDay(for: $0) }
            if groups[key] == nil {
                groups[key] = []
                order.append(key)
            }
            groups[key]?.append(photo)
        }

        return order.map { key in
            let title = key.map { sectionTitle(for: $0, calendar: calendar) } ?? "날짜 정보 없음"
            return PhotoSection(title: title, photos: groups[key] ?? [])
        }
    }

    private static func sectionTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) {
            return "오늘"
        }
        if calendar.isDateInYesterday(date) {
            return "어제"
        }
        return dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter
    }()
}
