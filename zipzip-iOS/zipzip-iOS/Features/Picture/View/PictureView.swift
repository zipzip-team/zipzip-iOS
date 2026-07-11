//
//  PictureView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/5/26.
//

import SwiftUI

struct PictureView: View {
    @Environment(Router.self) private var router
    let viewModel: PictureViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("사진")
                    .font(.t1_sb)
                    .foregroundStyle(.grey900)
                    .frame(height: 44)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 16)
                    .opacity(viewModel.isSelectionMode ? 0 : 1)

                PhotoRecommendationPlaceholder()

                PhotoGallery(
                    sections: viewModel.sections,
                    isSelectionMode: viewModel.isSelectionMode,
                    selectedPhotoIDs: viewModel.selectedPhotoIDs,
                    onTapPhoto: viewModel.toggleSelection,
                    onLongPressPhoto: viewModel.handleLongPress,
                    onOpenPhoto: { router.push(.photoDetail($0)) }
                )
                .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.orange30.ignoresSafeArea())
        .task { await viewModel.loadPhotos() }
        .overlay(alignment: .topTrailing) {
            if !viewModel.isSelectionMode {
                floatingButton
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
            onPrimaryTap: { viewModel.showDeleteAlert = false } // TODO: 삭제 실행 연결
        )
    }

    private var floatingButton: some View {
        RoundedIconButton(items: [
            .init(id: "filter", icon: .filter, accessibilityLabel: "필터") { router.push(.filter) },
            .init(id: "selection", icon: .select, accessibilityLabel: "사진 선택") {
                viewModel.enterSelectionMode()
            }
        ])
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var cancelButton: some View {
        RoundedTextButton(title: "취소", style: .cancel) {
            viewModel.cancelSelection()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

private struct PhotoRecommendationPlaceholder: View {
    var body: some View {
        Color.grey100
            .frame(height: 207)
            .accessibilityHidden(true)
    }
}

#Preview {
    PictureView(viewModel: PictureViewModel())
        .environment(Router())
}
