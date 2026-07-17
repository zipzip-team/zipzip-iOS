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

    private let albumColumns = [
        GridItem(.flexible(), spacing: 17),
        GridItem(.flexible(), spacing: 17)
    ]

    var body: some View {
        ZStack {
            Color.orange30
                .ignoresSafeArea()

            VStack(spacing: 8) {
                header
                content
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadPhotos()
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            RoundedTextButton(title: "취소", style: .cancel) {
                dismiss()
            }

            Spacer()

            if viewModel.showsAlbumTab {
                HStack(spacing: 12) {
                    SelectableButton(
                        title: "사진",
                        isSelected: viewModel.importTab == .left,
                        selectedColor: .orange500
                    ) {
                        viewModel.selectImportTab(.left)
                    }
                    SelectableButton(
                        title: "사진집",
                        isSelected: viewModel.importTab == .right,
                        selectedColor: .orange500
                    ) {
                        viewModel.selectImportTab(.right)
                    }
                }

                Spacer()
            }

            completionButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    @ViewBuilder private var content: some View {
        if viewModel.showsAlbumTab, viewModel.importTab == .right {
            if viewModel.selectedAlbum != nil {
                photoGrid(sections: viewModel.albumSections)
            } else {
                albumList
            }
        } else {
            photoGrid(sections: viewModel.sections)
        }
    }

    private func photoGrid(sections: [PhotoSection]) -> some View {
        ScrollView(showsIndicators: false) {
            PhotoGallery(
                sections: sections,
                isSelectionMode: true,
                selectedPhotoIDs: viewModel.selectedPhotoIDs(in: sections),
                onTapPhoto: { viewModel.toggleSelection($0, in: sections) }
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    private var albumList: some View {
        ScrollView(showsIndicators: false) {
            if viewModel.albums.isEmpty {
                ContentUnavailableView(
                    "불러올 사진집이 없어요",
                    systemImage: "photo.on.rectangle.angled"
                )
                .foregroundStyle(.grey500)
                .frame(maxWidth: .infinity)
                .padding(.top, 120)
            } else {
                LazyVGrid(columns: albumColumns, spacing: 20) {
                    ForEach(viewModel.albums) { album in
                        Button {
                            Task { await viewModel.selectImportAlbum(album) }
                        } label: {
                            AlbumCard(
                                name: album.name,
                                count: album.count,
                                thumbnailLocalIdentifiers: album.thumbnailLocalIdentifiers
                            )
                        }
                        .buttonStyle(StaticButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private var completionButton: some View {
        RoundedTextButton(title: "완료", style: .cancel) {
            Task {
                if await viewModel.completeSelection() {
                    dismiss()
                }
            }
        }
        .disabled(viewModel.isCompletionDisabled)
        .opacity(viewModel.isCompletionDisabled ? 0.4 : 1)
    }
}

#Preview("Album Photo Picker", traits: .fixedLayout(width: 390, height: 844)) {
    NavigationStack {
        AlbumPhotoPickerView(
            viewModel: AlbumPhotoPickerViewModel(
                onComplete: { _ in true }
            )
        )
    }
}
