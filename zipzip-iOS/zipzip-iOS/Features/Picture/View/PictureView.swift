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
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("사진")
                    .font(.t1_sb)
                    .foregroundStyle(.grey900)
                    .frame(height: 44)
                    .padding(.vertical, 4)
                    .opacity(viewModel.isSelectionMode ? 0 : 1)

                PhotoGallery(
                    sections: viewModel.sections,
                    isSelectionMode: viewModel.isSelectionMode,
                    selectedPhotoIDs: viewModel.selectedPhotoIDs,
                    onTapPhoto: viewModel.toggleSelection,
                    onLongPressPhoto: viewModel.handleLongPress
                )
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.orange30.ignoresSafeArea())
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
    }

    private var floatingButton: some View {
        RoundedIconButton(items: [
            .init(id: "filter", icon: .iconFilter) { router.push(.filter) },
            .init(id: "selection", icon: .iconSelection) { viewModel.enterSelectionMode() }
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

#Preview {
    PictureView(viewModel: PictureViewModel())
        .environment(Router())
}
