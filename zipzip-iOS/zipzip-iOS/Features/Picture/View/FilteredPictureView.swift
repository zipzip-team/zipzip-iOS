//
//  FilteredPictureView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct FilteredPictureView: View {
    @Environment(Router.self) private var router

    @State private var appliedFilters: [AppliedFilter]
    @State private var showDeviceSheet = false
    @State private var pickerDevice = ""

    private let sections: [PhotoSection] = PhotoSection.sample
    private let devices: [FilterDevice] = PhotoFilterOptions.sample.devices

    init(appliedFilters: [AppliedFilter]) {
        _appliedFilters = State(initialValue: appliedFilters)
    }

    var body: some View {
        VStack(spacing: 8) {
            topBar
            ScrollView {
                PhotoGallery(sections: sections)
                    .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.orange30.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .bottomSheet(isPresented: $showDeviceSheet, detents: [.content]) { dismiss in
            DeviceFilterSheet(devices: devices, selected: $pickerDevice) {
                applyDevice(pickerDevice)
                dismiss()
            }
        }
        .overlay(alignment: .bottom) {
            filterChipBar
        }
    }

    private var topBar: some View {
        HStack {
            RoundedIconButton(items: [
                .init(id: "back", icon: .iconChevronLeft) { router.pop() }
            ])
            Spacer()
            RoundedIconButton(items: [
                .init(id: "selection", icon: .iconSelection) { /* TODO: 선택 모드 */ }
            ])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var filterChipBar: some View {
        HStack(spacing: 10) {
            ForEach(appliedFilters, id: \.self) { filter in
                AppliedFilterChip(filter: filter) { editFilter(filter) }
            }
            AddFilterChip { router.pop() }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func editFilter(_ filter: AppliedFilter) {
        switch filter.kind {
        case .device:
            pickerDevice = filter.value
            showDeviceSheet = true
        case .location:
            break // TODO: 바텀시트로 장소 필터 편집
        case .date:
            break // TODO: 바텀시트로 날짜 필터 편집
        case .etc:
            break // TODO: 바텀시트로 기타 필터 편집
        }
    }

    private func applyDevice(_ name: String) {
        guard let index = appliedFilters.firstIndex(where: { $0.kind == .device }) else { return }
        appliedFilters[index] = AppliedFilter(kind: .device, value: name)
    }
}

#Preview {
    FilteredPictureView(appliedFilters: [
        AppliedFilter(kind: .device, value: "iphone 6"),
        AppliedFilter(kind: .location, value: "오사카")
    ])
    .environment(Router())
}
