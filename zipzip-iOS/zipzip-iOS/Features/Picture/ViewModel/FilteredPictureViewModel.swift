//
//  FilteredPictureViewModel.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/9/26.
//

import Foundation
import OSLog
import SQLiteData
import SwiftUI

@Observable
final class FilteredPictureViewModel {
    @ObservationIgnored
    @Dependency(\.photoFilterOptions) private var optionsProvider

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zipzip-iOS",
        category: "FilteredOptions"
    )

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

    init(appliedFilters: [AppliedFilter]) {
        self.appliedFilters = appliedFilters
    }

    func loadOptions() async {
        do {
            options = try await optionsProvider.load()
        } catch {
            Self.logger.error("failed to load filter options: \(error)")
        }
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
        applyFilter(kind: .device, value: name.isEmpty ? nil : name)
    }

    func applyLocation(_ name: String) {
        applyFilter(kind: .location, value: name.isEmpty ? nil : name)
    }

    func applyDate(_ date: Date?) {
        applyFilter(kind: .date, value: date.map(AppliedFilter.dateText))
    }

    func applyEtc(_ value: String) {
        applyFilter(kind: .etc, value: value.isEmpty ? nil : value)
    }

    private func applyFilter(kind: FilterKind, value: String?) {
        guard let index = appliedFilters.firstIndex(where: { $0.kind == kind }) else { return }

        guard let value else {
            appliedFilters.remove(at: index)
            return
        }

        appliedFilters[index] = AppliedFilter(kind: kind, value: value)
    }
}
