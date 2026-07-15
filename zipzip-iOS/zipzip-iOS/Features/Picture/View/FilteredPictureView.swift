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
    private let albumViewModel: AlbumViewModel
    private let shareViewModel: ShareViewModel

    init(
        appliedFilters: [AppliedFilter],
        albumViewModel: AlbumViewModel,
        shareViewModel: ShareViewModel
    ) {
        _viewModel = State(initialValue: FilteredPictureViewModel(appliedFilters: appliedFilters))
        self.albumViewModel = albumViewModel
        self.shareViewModel = shareViewModel
    }

    var body: some View {
        @Bindable var pictureViewModel = pictureViewModel
        @Bindable var viewModel = viewModel

        return VStack(spacing: 8) {
            Color.clear
                .frame(height: FloatingHeaderLayout.buttonHeight + 8)

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
        .task { await viewModel.loadOptions() }
        .task(id: viewModel.appliedFilters) {
            await pictureViewModel.applyFilters(viewModel.appliedFilters)
        }
        .alert("필터 정보를 불러오지 못했어요.", isPresented: $viewModel.isErrorAlertPresented) {
            Button("다시 시도") {
                Task { await viewModel.loadOptions() }
            }
            Button("확인", role: .cancel) {}
        }
        .bottomSheet(isPresented: $viewModel.showDeviceSheet, detents: [.content]) { dismiss in
            DeviceFilterSheet(
                devices: viewModel.options.devices,
                selected: $viewModel.pickerDevice,
                onReset: { viewModel.pickerDevice = "" }
            ) {
                viewModel.applyDevice(viewModel.pickerDevice)
                dismiss()
            }
        }
        .bottomSheet(isPresented: $viewModel.showLocationSheet, detents: [.content]) { dismiss in
            LocationFilterSheet(
                locations: viewModel.options.locations,
                selected: $viewModel.pickerLocation,
                onReset: { viewModel.pickerLocation = "" }
            ) {
                viewModel.applyLocation(viewModel.pickerLocation)
                dismiss()
            }
        }
        .bottomSheet(isPresented: $viewModel.showDateSheet, detents: [.height(dateSheetHeight)]) { dismiss in
            DateFilterSheet(date: $viewModel.pickerDate, onReset: {
                viewModel.pickerDate = nil
            }) {
                viewModel.applyDate(viewModel.pickerDate)
                dismiss()
            }
        }
        .bottomSheet(isPresented: $viewModel.showEtcSheet, detents: [.content]) { dismiss in
            EtcFilterSheet(
                items: viewModel.options.etcItems,
                selected: $viewModel.pickerEtc,
                onReset: { viewModel.pickerEtc = "" }
            ) {
                viewModel.applyEtc(viewModel.pickerEtc)
                dismiss()
            }
        }
        .bottomSheet(isPresented: $showShareSheet, detents: [.full]) { dismiss in
            ShareSheet(
                albums: albumViewModel.shareDestinations,
                shareAlbums: shareViewModel.groups,
                onDismiss: { dismiss() },
                onOpenShareAlbum: loadSharedAlbums,
                onComplete: { destinations in
                    let localIdentifiers = pictureViewModel.selectedPhotoLocalIdentifiers
                    Task {
                        guard await albumViewModel.addPhotos(
                            localIdentifiers: localIdentifiers,
                            to: destinations
                        ) else {
                            return
                        }

                        dismiss()
                        pictureViewModel.cancelSelection()
                        guard let albumID = destinations.firstPersonalAlbumID else {
                            return
                        }

                        router.push(.albumDetail(albumID))
                    }
                }
            )
        }
        .bottomSheetAlert(
            isPresented: $pictureViewModel.showDeleteAlert,
            title: "이 사진을 삭제하시겠어요?",
            message: "삭제하면 집집과 사진 앱에서 모두 사라져요.",
            secondaryTitle: "취소",
            primaryTitle: "삭제",
            onSecondaryTap: { pictureViewModel.showDeleteAlert = false },
            onPrimaryTap: {
                pictureViewModel.showDeleteAlert = false
                Task { await pictureViewModel.deleteSelectedPhotos() }
            }
        )
        .alert("요청을 완료하지 못했어요.", isPresented: $pictureViewModel.isErrorAlertPresented) {
            Button("확인", role: .cancel, action: pictureViewModel.dismissErrorAlert)
        } message: {
            Text(pictureViewModel.errorAlertMessage)
        }
        .overlay(alignment: .topLeading) {
            FloatingHeaderBar {
                topBar
            }
        }
        .overlay(alignment: .bottom) {
            if pictureViewModel.isSelectionMode {
                actionBar
            } else {
                filterChipBar
            }
        }
    }

    private func loadSharedAlbums(groupID: ShareAlbum.ID) async {
        await shareViewModel.loadSharedAlbums(groupID: groupID)
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
    }

    private var actionBar: some View {
        let hasSelection = !pictureViewModel.selectedPhotoIDs.isEmpty
        return ActionBar(items: [
            .init(icon: .moveToAlbum, title: "집으로", isDisabled: !hasSelection) {
                showShareSheet = true
            },
            .init(icon: .metadata, title: "정보 수정", isDisabled: !hasSelection) {
                if let metadata = pictureViewModel.firstSelectedMetadata {
                    router.push(.photoInfoEdit(PhotoInfoEditDestination(
                        metadata: metadata,
                        localIdentifiers: pictureViewModel.selectedPhotoLocalIdentifiers,
                        onSuccessfulDismiss: pictureViewModel.cancelSelection
                    )))
                }
            },
            .init(icon: .delete, title: "삭제", isDisabled: !hasSelection) {
                pictureViewModel.requestDelete()
            }
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
        let bottomInset = window?.safeAreaInsets.bottom ?? 0
        let visibleContentBelowSafeArea: CGFloat = 169
        return max(screenHeight - topInset - visibleContentBelowSafeArea - bottomInset, 1)
    }
}

#Preview {
    let container = DIContainer()
    FilteredPictureView(
        appliedFilters: [
            AppliedFilter(kind: .device, value: "iphone 6"),
            AppliedFilter(kind: .location, value: "오사카")
        ],
        albumViewModel: AlbumViewModel(albums: AlbumViewItem.samples),
        shareViewModel: ShareViewModel(repository: container.shareGroupRepository)
    )
    .environment(container)
    .environment(Router())
}
