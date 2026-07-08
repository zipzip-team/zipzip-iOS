//
//  FilterViewModel.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

@Observable
final class FilterViewModel {
    let options: PhotoFilterOptions = .sample

    var selectedDevice: String?
    var selectedLocation: String?
    var selectedDate: Date?
    var selectedEtc: String?

    var appliedFilters: [AppliedFilter] {
        [
            selectedDevice.map { AppliedFilter(kind: .device, value: $0) },
            selectedLocation.map { AppliedFilter(kind: .location, value: $0) },
            selectedDate.map { AppliedFilter(kind: .date, value: Self.dateText($0)) },
            selectedEtc.map { AppliedFilter(kind: .etc, value: $0) }
        ].compactMap { $0 }
    }

    var displayDateText: String {
        selectedDate.map(Self.dateText) ?? options.dateText
    }

    func selectDevice(_ name: String) {
        selectedDevice = name
    }

    func selectLocation(_ name: String) {
        selectedLocation = name
    }

    func selectDate(_ date: Date) {
        selectedDate = date
    }

    func selectEtc(_ name: String) {
        selectedEtc = name
    }

    func reset() {
        selectedDevice = nil
        selectedLocation = nil
        selectedDate = nil
        selectedEtc = nil
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter
    }()

    private static func dateText(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
