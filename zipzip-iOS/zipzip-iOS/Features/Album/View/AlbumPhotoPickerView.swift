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
                    AlbumPhotoPickerGallery(
                        sections: sections,
                        selectedPhotoIDs: $selectedPhotoIDs
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
}

private struct AlbumPhotoPickerGallery: View {
    let sections: [PhotoSection]
    @Binding var selectedPhotoIDs: [UUID]

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 4
    )

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.b2_sb)
                        .foregroundStyle(.grey1000)

                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(section.photos) { photo in
                            AlbumPhotoPickerCell(
                                photo: photo,
                                selectionNumber: selectionNumber(for: photo.id),
                                onTap: { toggleSelection(for: photo.id) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func toggleSelection(for id: UUID) {
        if let index = selectedPhotoIDs.firstIndex(of: id) {
            selectedPhotoIDs.remove(at: index)
        } else {
            selectedPhotoIDs.append(id)
        }
    }

    private func selectionNumber(for id: UUID) -> Int? {
        selectedPhotoIDs.firstIndex(of: id).map { $0 + 1 }
    }
}

private struct AlbumPhotoPickerCell: View {
    let photo: Photo
    let selectionNumber: Int?
    let onTap: () -> Void

    private var isSelected: Bool {
        selectionNumber != nil
    }

    var body: some View {
        Button(action: onTap) {
            Color.grey200
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if isSelected {
                        Rectangle()
                            .strokeBorder(.orange500, lineWidth: 2)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Indicator(
                        title: selectionNumber.map(String.init),
                        status: isSelected ? .selected : .default
                    )
                    .padding(6)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("사진")
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityValue: String {
        if let selectionNumber {
            return "\(selectionNumber)번째 선택됨"
        }

        return "선택 안 됨"
    }
}

#Preview("Album Photo Picker", traits: .fixedLayout(width: 390, height: 844)) {
    NavigationStack {
        AlbumPhotoPickerView()
    }
}
