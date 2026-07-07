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
        Color.grey200
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .bottomTrailing) {
                if isSelectionMode {
                    Indicator(title: badgeTitle(photo.id), status: badgeStatus(photo.id))
                        .padding(6)
                }
            }
            .contentShape(.rect)
            .onTapGesture {
                if isSelectionMode {
                    onTapPhoto?(photo.id)
                } else {
                    onOpenPhoto?(photo)
                }
            }
            .onLongPressGesture { onLongPressPhoto?(photo.id) }
    }

    private func badgeStatus(_ id: UUID) -> Indicator.Status {
        selectedPhotoIDs.contains(id) ? .selected : .default
    }

    private func badgeTitle(_ id: UUID) -> String? {
        selectedPhotoIDs.firstIndex(of: id).map { "\($0 + 1)" }
    }
}

#Preview {
    ScrollView {
        PhotoGallery(sections: PhotoSection.sample)
            .padding(.horizontal, 16)
    }
}
