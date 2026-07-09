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
            selectedDate.map { AppliedFilter(kind: .date, value: AppliedFilter.dateText($0)) },
            selectedEtc.map { AppliedFilter(kind: .etc, value: $0) }
        ].compactMap { $0 }
    }

    var displayDateText: String? {
        selectedDate.map(AppliedFilter.dateText)
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
}
