//
//  DateFilterSheet.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct DateFilterSheet: View {
    @Binding var date: Date?
    let onReset: () -> Void
    let onDone: () -> Void

    @State private var photosVM = DateFilterPhotosViewModel()

    var body: some View {
        BottomSheet(
            leftItem: {
                headerButton(title: "초기화", action: onReset)
            },
            rightItem: {
                headerButton(title: "완료", action: onDone)
            }
        ) {
            VStack(alignment: .leading, spacing: 20) {
                PhotoCalendarView(selection: $date, availableDays: photosVM.availableDays)
                    .background(.grey1000, in: .rect(cornerRadius: 12))

                photosBlock
            }
            .padding(.horizontal, 16)
        }
        .task { await photosVM.load() }
    }

    private func headerButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.b1_sb)
                .foregroundStyle(.white00)
                .frame(width: 72, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var photosBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이 날의 사진들을 확인해보세요!")
                .font(.b2_md)
                .foregroundStyle(.white00)

            let photos = photosVM.photos(on: date)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 4) {
                    ForEach(photos) { photo in
                        PhotoThumbnail(image: photosVM.thumbnailImages[photo.localIdentifier])
                            .frame(width: 88, height: 88)
                            .task(id: photo.localIdentifier) {
                                await photosVM.loadThumbnail(for: photo.localIdentifier)
                            }
                    }
                }
            }
            .frame(height: 88)
        }
    }
}

#Preview {
    DateFilterSheet(date: .constant(Date()), onReset: {}, onDone: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(.black)
}
