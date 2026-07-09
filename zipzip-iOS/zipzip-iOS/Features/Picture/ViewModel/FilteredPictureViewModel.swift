//
//  FilteredPictureViewModel.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/9/26.
//

import SwiftUI

@Observable
final class FilteredPictureViewModel {
    let options: PhotoFilterOptions = .sample

    var appliedFilters: [AppliedFilter]

    var showDeviceSheet = false
    var pickerDevice = ""
    var showLocationSheet = false
    var pickerLocation = ""
    var showDateSheet = false
    var pickerDate = Date()
    var showEtcSheet = false
    var pickerEtc = ""

    init(appliedFilters: [AppliedFilter]) {
        self.appliedFilters = appliedFilters
    }

    func editFilter(_ filter: AppliedFilter) {
        switch filter.kind {
        case .device:
            pickerDevice = filter.value
            showDeviceSheet = true
        case .location:
            pickerLocation = filter.value
            showLocationSheet = true
        case .date:
            pickerDate = AppliedFilter.date(from: filter.value) ?? Date()
            showDateSheet = true
        case .etc:
            pickerEtc = filter.value
            showEtcSheet = true
        }
    }

    func applyDevice(_ name: String) {
        guard let index = appliedFilters.firstIndex(where: { $0.kind == .device }) else { return }
        appliedFilters[index] = AppliedFilter(kind: .device, value: name)
    }

    func applyLocation(_ name: String) {
        guard let index = appliedFilters.firstIndex(where: { $0.kind == .location }) else { return }
        appliedFilters[index] = AppliedFilter(kind: .location, value: name)
    }

    func applyDate(_ date: Date) {
        guard let index = appliedFilters.firstIndex(where: { $0.kind == .date }) else { return }
        appliedFilters[index] = AppliedFilter(kind: .date, value: AppliedFilter.dateText(date))
    }

    func applyEtc(_ value: String) {
        guard let index = appliedFilters.firstIndex(where: { $0.kind == .etc }) else { return }
        appliedFilters[index] = AppliedFilter(kind: .etc, value: value)
    }
}
