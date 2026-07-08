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
    var selectedEtc: String?

    var appliedFilters: [AppliedFilter] {
        [
            selectedDevice.map { AppliedFilter(kind: .device, value: $0) },
            selectedLocation.map { AppliedFilter(kind: .location, value: $0) },
            selectedEtc.map { AppliedFilter(kind: .etc, value: $0) }
        ].compactMap { $0 }
    }

    func selectDevice(_ name: String) {
        selectedDevice = name
    }

    func selectLocation(_ name: String) {
        selectedLocation = name
    }

    func selectEtc(_ name: String) {
        selectedEtc = name
    }

    func reset() {
        selectedDevice = nil
        selectedLocation = nil
        selectedEtc = nil
    }
}
