//
//  FilterViewModel.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import Foundation
import OSLog
import SQLiteData
import SwiftUI

@Observable
final class FilterViewModel {
    @ObservationIgnored
    @Dependency(\.photoFilterOptions) private var provider

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zipzip-iOS",
        category: "FilterOptions"
    )

    private(set) var options = PhotoFilterOptions(
        devices: [],
        locations: [],
        etcItems: PhotoFilterOptions.defaultEtcItems
    )

    var selectedDevices: Set<String> = []
    var selectedLocations: Set<String> = []
    var selectedDate: Date?
    var selectedEtcItems: Set<String> = []

    var appliedFilters: [AppliedFilter] {
        var filters: [AppliedFilter] = []
        filters += selectedDevices.sorted().map { AppliedFilter(kind: .device, value: $0) }
        filters += selectedLocations.sorted().map { AppliedFilter(kind: .location, value: $0) }
        if let selectedDate {
            filters.append(AppliedFilter(kind: .date, value: AppliedFilter.dateText(selectedDate)))
        }
        filters += selectedEtcItems.sorted().map { AppliedFilter(kind: .etc, value: $0) }
        return filters
    }

    var displayDateText: String? {
        selectedDate.map(AppliedFilter.dateText)
    }

    func selectDevice(_ name: String) {
        toggle(name, in: &selectedDevices)
    }

    func selectLocation(_ name: String) {
        toggle(name, in: &selectedLocations)
    }

    func selectDate(_ date: Date?) {
        selectedDate = date
    }

    func selectEtc(_ name: String) {
        toggle(name, in: &selectedEtcItems)
    }

    private func toggle(_ value: String, in set: inout Set<String>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }

    func reset() {
        selectedDevices.removeAll()
        selectedLocations.removeAll()
        selectedDate = nil
        selectedEtcItems.removeAll()
    }

    func loadOptions() async {
        do {
            options = try await provider.load()
        } catch {
            Self.logger.error("failed to load filter options: \(error)")
        }
    }
}
