//
//  PictureView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/5/26.
//

import SwiftUI

struct PictureView: View {
    @AppStorage("hasSeenPictureIntroduction") private var hasSeenPictureIntroduction = false
    @State private var showPictureIntroduction = false

    let viewModel: PictureViewModel
    let onOpenFilter: () -> Void
    let onOpenPhoto: (Photo) -> Void

    init(
        viewModel: PictureViewModel,
        onOpenFilter: @escaping () -> Void = {},
        onOpenPhoto: @escaping (Photo) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onOpenFilter = onOpenFilter
        self.onOpenPhoto = onOpenPhoto
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ScrollableHeaderTitle("사진", isVisible: !viewModel.isSelectionMode)

                PhotoGallery(
                    sections: viewModel.sections,
                    isSelectionMode: viewModel.isSelectionMode,
                    selectedPhotoIDs: viewModel.selectedPhotoIDs,
                    onTapPhoto: viewModel.toggleSelection,
                    onLongPressPhoto: viewModel.handleLongPress,
                    onOpenPhoto: onOpenPhoto
                )
                .padding(.horizontal, 16)
            }
        }
        .ignoresSafeArea(edges: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.orange30.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            FloatingHeader(.trailing) {
                if !viewModel.isSelectionMode {
                    floatingButton
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if viewModel.isSelectionMode {
                cancelButton
            }
        }
        .bottomSheetAlert(
            isPresented: $viewModel.showDeleteAlert,
            title: "이 사진을 삭제하시겠어요?",
            message: "삭제하면 집집과 사진 앱에서 모두 사라져요.",
            secondaryTitle: "취소",
            primaryTitle: "삭제",
            onSecondaryTap: { viewModel.showDeleteAlert = false },
            onPrimaryTap: {
                viewModel.showDeleteAlert = false
                Task { await viewModel.deleteSelectedPhotos() }
            }
        )
        .bottomSheetAlert(
            isPresented: $showPictureIntroduction,
            title: "세컨폰·디카 사진만 모아봤어요.",
            message: "날짜와 장소가 어긋난 사진을 바로잡고,\n필요한 사진을 쉽게 찾아 앨범을 정리할 수 있어요.",
            primaryTitle: "사진 정리하기",
            onPrimaryTap: { showPictureIntroduction = false }
        )
        .onAppear {
            guard !hasSeenPictureIntroduction else { return }
            hasSeenPictureIntroduction = true
            showPictureIntroduction = true
        }
    }

    private var floatingButton: some View {
        RoundedIconButton(items: [
            .init(id: "filter", icon: .filter, accessibilityLabel: "필터", action: onOpenFilter),
            .init(id: "selection", icon: .select, accessibilityLabel: "사진 선택") {
                viewModel.enterSelectionMode()
            }
        ])
    }

    private var cancelButton: some View {
        RoundedTextButton(title: "취소", style: .cancel) {
            viewModel.cancelSelection()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

#Preview {
    PictureView(viewModel: PictureViewModel())
}
