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
    private let onComplete: ([UUID]) -> Void

    init(
        sections: [PhotoSection] = PhotoSection.sample,
        selectedPhotoIDs: [UUID] = [],
        onComplete: @escaping ([UUID]) -> Void = { _ in }
    ) {
        self.sections = sections
        _selectedPhotoIDs = State(initialValue: selectedPhotoIDs)
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            Color.orange30
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                PhotoGallery(
                    sections: sections,
                    isSelectionMode: true,
                    selectedPhotoIDs: selectedPhotoIDs,
                    onTapPhoto: toggleSelection
                )
                .padding(.horizontal, 16)
                .padding(.top, 79)
                .padding(.bottom, 40)
            }
        }
        .overlay(alignment: .topLeading) {
            cancelButton
                .padding(.top, 19)
                .padding(.leading, 16)
        }
        .overlay(alignment: .topTrailing) {
            completionButton
                .padding(.top, 19)
                .padding(.trailing, 16)
        }
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var cancelButton: some View {
        RoundedTextButton(title: "취소", style: .cancel) {
            dismiss()
        }
    }

    private var completionButton: some View {
        RoundedTextButton(title: "완료", style: .cancel) {
            onComplete(selectedPhotoIDs)
            dismiss()
        }
        .disabled(selectedPhotoIDs.isEmpty)
        .opacity(selectedPhotoIDs.isEmpty ? 0.4 : 1)
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
