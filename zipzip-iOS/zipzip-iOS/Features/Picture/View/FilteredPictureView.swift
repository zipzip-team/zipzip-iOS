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
    @State private var viewModel: FilteredPictureViewModel
    @State private var showShareSheet = false

    init(appliedFilters: [AppliedFilter]) {
        _viewModel = State(initialValue: FilteredPictureViewModel(appliedFilters: appliedFilters))
    }

    var body: some View {
        @Bindable var pictureViewModel = pictureViewModel
        @Bindable var viewModel = viewModel

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
        .bottomSheet(isPresented: $viewModel.showDeviceSheet, detents: [.content]) { dismiss in
            DeviceFilterSheet(devices: viewModel.options.devices, selected: $viewModel.pickerDevice) {
                viewModel.applyDevice(viewModel.pickerDevice)
                dismiss()
            }
        }
        .bottomSheet(isPresented: $viewModel.showLocationSheet, detents: [.content]) { dismiss in
            LocationFilterSheet(locations: viewModel.options.locations, selected: $viewModel.pickerLocation) {
                viewModel.applyLocation(viewModel.pickerLocation)
                dismiss()
            }
        }
        .bottomSheet(isPresented: $viewModel.showDateSheet, detents: [.height(dateSheetHeight)]) { dismiss in
            DateFilterSheet(date: $viewModel.pickerDate) {
                viewModel.applyDate(viewModel.pickerDate)
                dismiss()
            }
        }
        .bottomSheet(isPresented: $viewModel.showEtcSheet, detents: [.content]) { dismiss in
            EtcFilterSheet(items: viewModel.options.etcItems, selected: $viewModel.pickerEtc) {
                viewModel.applyEtc(viewModel.pickerEtc)
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
                    .init(id: "back", icon: .chevronLeft, accessibilityLabel: "뒤로가기") { router.pop() }
                ])
            }
            Spacer()
            if !pictureViewModel.isSelectionMode {
                RoundedIconButton(items: [
                    .init(id: "selection", icon: .select, accessibilityLabel: "사진 선택") {
                        pictureViewModel.enterSelectionMode()
                    }
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
            ForEach(viewModel.appliedFilters, id: \.self) { filter in
                AppliedFilterChip(filter: filter) { viewModel.editFilter(filter) }
            }
            AddFilterChip { router.pop() }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
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
