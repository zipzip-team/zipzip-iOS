//
//  FilteredPictureViewModel.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/9/26.
//

import OSLog
import SQLiteData
import SwiftUI

@Observable
final class FilteredPictureViewModel {
    @ObservationIgnored
    @Dependency(\.photoFilterOptions) private var optionsProvider

    private static let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "FilteredOptions")

    private(set) var options = PhotoFilterOptions(
        devices: [],
        locations: [],
        etcItems: PhotoFilterOptions.defaultEtcItems
    )

    var appliedFilters: [AppliedFilter]

    var showDeviceSheet = false
    var pickerDevice = ""
    var showLocationSheet = false
    var pickerLocation = ""
    var showDateSheet = false
    var pickerDate: Date?
    var showEtcSheet = false
    var pickerEtc = ""
    var isErrorAlertPresented = false

    private var editingFilter: AppliedFilter?

    init(appliedFilters: [AppliedFilter]) {
        self.appliedFilters = appliedFilters
    }

    func loadOptions() async {
        do {
            options = try await optionsProvider.load()
        } catch {
            Self.logger.error("failed to load filter options: \(error)")
            isErrorAlertPresented = true
        }
    }

    func editFilter(_ filter: AppliedFilter) {
        editingFilter = filter
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
        replaceEditingFilter(with: name.isEmpty ? nil : name)
    }

    func applyLocation(_ name: String) {
        replaceEditingFilter(with: name.isEmpty ? nil : name)
    }

    func applyDate(_ date: Date?) {
        replaceEditingFilter(with: date.map(AppliedFilter.dateText))
    }

    func applyEtc(_ value: String) {
        replaceEditingFilter(with: value.isEmpty ? nil : value)
    }

    /// 편집 중인 칩(값 단위)만 교체·삭제한다. 같은 종류 칩이 여러 개여도 정확히 해당 칩만 바뀐다.
    private func replaceEditingFilter(with value: String?) {
        defer { editingFilter = nil }
        guard let editing = editingFilter,
              let index = appliedFilters.firstIndex(of: editing)
        else {
            return
        }

        guard let value, !value.isEmpty else {
            appliedFilters.remove(at: index)
            return
        }

        let replacement = AppliedFilter(kind: editing.kind, value: value)
        if value != editing.value, appliedFilters.contains(replacement) {
            appliedFilters.remove(at: index)
        } else {
            appliedFilters[index] = replacement
        }
    }
}
