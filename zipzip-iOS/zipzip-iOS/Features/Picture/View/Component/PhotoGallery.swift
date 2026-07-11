//
//  PhotoGallery.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct PhotoGallery: View {
    let sections: [PhotoSection]
    var isSelectionMode: Bool = false
    var selectedPhotoIDs: [UUID] = []
    var onTapPhoto: ((UUID) -> Void)? = nil
    var onLongPressPhoto: ((UUID) -> Void)? = nil
    var onOpenPhoto: ((Photo) -> Void)? = nil

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
                            photoCell(photo)
                        }
                    }
                }
            }
        }
    }

    private func photoCell(_ photo: Photo) -> some View {
        PhotoThumbnail(localIdentifier: photo.localIdentifier)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if isSelectionMode, selectedPhotoIDs.contains(photo.id) {
                    Rectangle()
                        .strokeBorder(.orange500, lineWidth: 2)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isSelectionMode {
                    Indicator(title: badgeTitle(photo.id), status: badgeStatus(photo.id))
                        .padding(6)
                }
            }
            .contentShape(.rect)
            .onTapGesture { handlePhotoTap(photo) }
            .onLongPressGesture { onLongPressPhoto?(photo.id) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("사진")
            .accessibilityValue(accessibilityValue(photo.id))
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelectionMode && selectedPhotoIDs.contains(photo.id) ? .isSelected : [])
            .accessibilityAction { handlePhotoTap(photo) }
    }

    private func handlePhotoTap(_ photo: Photo) {
        if isSelectionMode {
            onTapPhoto?(photo.id)
        } else {
            onOpenPhoto?(photo)
        }
    }

    private func badgeStatus(_ id: UUID) -> Indicator.Status {
        selectedPhotoIDs.contains(id) ? .selected : .default
    }

    private func badgeTitle(_ id: UUID) -> String? {
        selectedPhotoIDs.firstIndex(of: id).map { "\($0 + 1)" }
    }

    private func accessibilityValue(_ id: UUID) -> String {
        guard isSelectionMode else {
            return ""
        }

        if let index = selectedPhotoIDs.firstIndex(of: id) {
            return "\(index + 1)번째 선택됨"
        }

        return "선택 안 됨"
    }
}

#Preview {
    ScrollView {
        PhotoGallery(sections: PhotoSection.sample)
            .padding(.horizontal, 16)
    }
}
