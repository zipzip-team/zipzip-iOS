//
//  AlbumPhotoPickerView.swift
//  zipzip-iOS
//
//  Created by mansuiki on 7/10/26.
//

import SwiftUI

struct AlbumPhotoPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AlbumPhotoPickerViewModel

    init(viewModel: AlbumPhotoPickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color.orange30
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                PhotoGallery(
                    sections: viewModel.sections,
                    isSelectionMode: true,
                    selectedPhotoIDs: viewModel.selectedPhotoIDs,
                    onTapPhoto: viewModel.toggleSelection
                )
                .padding(.horizontal, 16)
                .padding(.top, 79)
                .padding(.bottom, 40)
            }
        }
        .overlay(alignment: .topLeading) {
            cancelButton
                .padding(.top, 14)
                .padding(.leading, 16)
        }
        .overlay(alignment: .topTrailing) {
            completionButton
                .padding(.top, 14)
                .padding(.trailing, 16)
        }
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadPhotos()
        }
    }

    private var cancelButton: some View {
        RoundedTextButton(title: "취소", style: .cancel) {
            dismiss()
        }
    }

    private var completionButton: some View {
        RoundedTextButton(title: "완료", style: .cancel) {
            viewModel.completeSelection()
            dismiss()
        }
        .disabled(viewModel.isCompletionDisabled)
        .opacity(viewModel.isCompletionDisabled ? 0.4 : 1)
    }
}

#Preview("Album Photo Picker", traits: .fixedLayout(width: 390, height: 844)) {
    NavigationStack {
        AlbumPhotoPickerView(
            viewModel: AlbumPhotoPickerViewModel(
                onComplete: { _ in }
            )
        )
    }
}
