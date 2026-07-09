//
//  FilteredPictureView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI
import UIKit

struct FilteredPictureView: View {
    @Environment(Router.self) private var router

    @State private var pictureViewModel = PictureViewModel()
    @State private var showShareSheet = false

    @State private var appliedFilters: [AppliedFilter]
    @State private var showDeviceSheet = false
    @State private var pickerDevice = ""
    @State private var showLocationSheet = false
    @State private var pickerLocation = ""
    @State private var showDateSheet = false
    @State private var pickerDate = Date()

    private let devices: [FilterDevice] = PhotoFilterOptions.sample.devices
    private let locations: [String] = PhotoFilterOptions.sample.locations

    init(appliedFilters: [AppliedFilter]) {
        _appliedFilters = State(initialValue: appliedFilters)
    }

    var body: some View {
        @Bindable var pictureViewModel = pictureViewModel

        return VStack(spacing: 8) {
            topBar
            ScrollView {
                PhotoGallery(
                    sections: pictureViewModel.sections,
                    isSelectionMode: pictureViewModel.isSelectionMode,
                    selectedPhotoIDs: pictureViewModel.selectedPhotoIDs,
                    onTapPhoto: pictureViewModel.toggleSelection,
                    onLongPressPhoto: pictureViewModel.handleLongPress,
                    onOpenPhoto: { router.push(.photoDetail($0)) }
                )
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
        .bottomSheet(isPresented: $showLocationSheet, detents: [.content]) { dismiss in
            LocationFilterSheet(locations: locations, selected: $pickerLocation) {
                applyLocation(pickerLocation)
                dismiss()
            }
        }
        .bottomSheet(isPresented: $showDateSheet, detents: [.height(dateSheetHeight)]) { dismiss in
            DateFilterSheet(date: $pickerDate) {
                applyDate(pickerDate)
                dismiss()
            }
        }
        .bottomSheet(isPresented: $showShareSheet, detents: [.full]) { dismiss in
            ShareSheet(
                albums: Album.samples,
                sharedAlbums: Album.sharedSamples,
                shareAlbums: ShareAlbum.samples,
                onDismiss: { dismiss() }
            )
        }
        .bottomSheetAlert(
            isPresented: $pictureViewModel.showDeleteAlert,
            title: "이 사진을 삭제하시겠어요?",
            message: "삭제하면 집집과 사진 앱에서 모두 사라져요.",
            secondaryTitle: "취소",
            primaryTitle: "삭제",
            onSecondaryTap: { pictureViewModel.showDeleteAlert = false },
            onPrimaryTap: { pictureViewModel.showDeleteAlert = false } // TODO: 삭제 실행 연결
        )
        .overlay(alignment: .bottom) {
            if pictureViewModel.isSelectionMode {
                actionBar
            } else {
                filterChipBar
            }
        }
    }

    private var topBar: some View {
        HStack {
            if pictureViewModel.isSelectionMode {
                RoundedTextButton(title: "취소", style: .cancel) {
                    pictureViewModel.cancelSelection()
                }
            } else {
                RoundedIconButton(items: [
                    .init(id: "back", icon: .iconChevronLeft) { router.pop() }
                ])
            }
            Spacer()
            if !pictureViewModel.isSelectionMode {
                RoundedIconButton(items: [
                    .init(id: "selection", icon: .iconSelection) { pictureViewModel.enterSelectionMode() }
                ])
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var actionBar: some View {
        ActionBar(items: [
            .init(icon: .moveToAlbum, title: "집으로") { showShareSheet = true },
            .init(icon: .metadata, title: "정보 수정") {
                if let metadata = pictureViewModel.firstSelectedMetadata {
                    router.push(.photoInfoEdit(metadata))
                }
            },
            .init(icon: .delete, title: "삭제") { pictureViewModel.requestDelete() }
        ])
        .padding(.bottom, 8)
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
            pickerLocation = filter.value
            showLocationSheet = true
        case .date:
            pickerDate = AppliedFilter.date(from: filter.value) ?? Date()
            showDateSheet = true
        case .etc:
            break // TODO: 바텀시트로 기타 필터 편집
        }
    }

    private func applyDevice(_ name: String) {
        guard let index = appliedFilters.firstIndex(where: { $0.kind == .device }) else { return }
        appliedFilters[index] = AppliedFilter(kind: .device, value: name)
    }

    private func applyLocation(_ name: String) {
        guard let index = appliedFilters.firstIndex(where: { $0.kind == .location }) else { return }
        appliedFilters[index] = AppliedFilter(kind: .location, value: name)
    }

    private func applyDate(_ date: Date) {
        guard let index = appliedFilters.firstIndex(where: { $0.kind == .date }) else { return }
        appliedFilters[index] = AppliedFilter(kind: .date, value: AppliedFilter.dateText(date))
    }

    private var dateSheetHeight: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        let screenHeight = window?.bounds.height ?? 0
        let topInset = window?.safeAreaInsets.top ?? 0
        let backButtonArea: CGFloat = 48
        let gap: CGFloat = 34
        return max(screenHeight - topInset - backButtonArea - gap, 1)
    }
}

#Preview {
    FilteredPictureView(appliedFilters: [
        AppliedFilter(kind: .device, value: "iphone 6"),
        AppliedFilter(kind: .location, value: "오사카")
    ])
    .environment(Router())
}
