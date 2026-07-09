//
//  AlbumPhotoPickerView.swift
//  zipzip-iOS
//
//  Created by mansuiki on 7/10/26.
//

import SwiftUI

struct AlbumPhotoPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoIDs: [UUID]

    private let sections: [PhotoSection]

    init(
        sections: [PhotoSection] = PhotoSection.sample,
        selectedPhotoIDs: [UUID] = []
    ) {
        self.sections = sections
        _selectedPhotoIDs = State(initialValue: selectedPhotoIDs)
    }

    var body: some View {
        ZStack {
            Color.orange30
                .ignoresSafeArea()

            VStack(spacing: 8) {
                topBar

                ScrollView(showsIndicators: false) {
                    PhotoGallery(
                        sections: sections,
                        isSelectionMode: true,
                        selectedPhotoIDs: selectedPhotoIDs,
                        onTapPhoto: toggleSelection
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .padding(.top, 19)
        }
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        HStack {
            RoundedTextButton(title: "취소", style: .cancel) {
                dismiss()
            }

            Spacer()

            RoundedTextButton(title: "완료", style: .cancel) {
                dismiss()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func toggleSelection(_ id: UUID) {
        if let index = selectedPhotoIDs.firstIndex(of: id) {
            selectedPhotoIDs.remove(at: index)
        } else {
            selectedPhotoIDs.append(id)
        }
    }
}

#Preview("Album Photo Picker", traits: .fixedLayout(width: 390, height: 844)) {
    NavigationStack {
        AlbumPhotoPickerView()
    }
}
