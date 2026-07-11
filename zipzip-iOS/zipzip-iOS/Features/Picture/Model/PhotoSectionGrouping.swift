//
//  PhotoSectionGrouping.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import Foundation

enum PhotoSectionGrouping {
    static func sections(
        from items: [(date: Date?, photo: Photo)],
        relativeTo referenceDate: Date = .now,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> [PhotoSection] {
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
            let title = key.map {
                sectionTitle(
                    for: $0,
                    relativeTo: referenceDate,
                    calendar: calendar,
                    locale: locale
                )
            } ?? "날짜 정보 없음"
            return PhotoSection(title: title, photos: groups[key] ?? [])
        }
    }

    private static func sectionTitle(
        for date: Date,
        relativeTo referenceDate: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        if calendar.isDate(date, inSameDayAs: referenceDate) {
            return "오늘"
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "어제"
        }

        let monthAndDayStyle = Date.FormatStyle(
            locale: locale,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        .month(.abbreviated)
        .day(.defaultDigits)

        if calendar.isDate(date, equalTo: referenceDate, toGranularity: .year) {
            return date.formatted(monthAndDayStyle)
        }

        return date.formatted(monthAndDayStyle.year(.defaultDigits))
    }
}
