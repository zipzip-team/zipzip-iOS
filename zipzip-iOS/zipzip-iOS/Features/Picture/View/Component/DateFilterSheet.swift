//
//  DateFilterSheet.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI
import UIKit

struct DateFilterSheet: View {
    @Binding var date: Date?
    @State private var photos: [Photo] = []
    @State private var isLoadErrorPresented = false
    let onReset: () -> Void
    let onDone: () -> Void

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
                MultiDatePicker("", selection: dateSelection)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    .colorScheme(.dark)
                    .padding(8)
                    .background(.grey1000, in: .rect(cornerRadius: 12))

                photosBlock
            }
            .padding(.horizontal, 16)
        }
        .task(id: date) {
            await loadPhotos()
        }
        .alert("사진을 불러오지 못했어요.", isPresented: $isLoadErrorPresented) {
            Button("다시 시도") {
                Task { await loadPhotos() }
            }
            Button("확인", role: .cancel) {}
        }
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

    private var dateSelection: Binding<Set<DateComponents>> {
        Binding {
            guard let date else { return [] }
            return [dateComponents(from: date)]
        } set: { newValue in
            let previousValue = date.map { Set([dateComponents(from: $0)]) } ?? []
            let selectedComponents = newValue.subtracting(previousValue).first ?? newValue.first
            date = selectedComponents.flatMap { Calendar.autoupdatingCurrent.date(from: $0) }
        }
    }

    private func dateComponents(from date: Date) -> DateComponents {
        Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: date)
    }

    private var photosBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이 날의 사진들을 확인해보세요!")
                .font(.b2_md)
                .foregroundStyle(.white00)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(0 ..< 6, id: \.self) { index in
                        if photos.indices.contains(index) {
                            DateFilterPhoto(localIdentifier: photos[index].localIdentifier)
                                .frame(width: 88, height: 88)
                        } else {
                            Color.grey200
                                .frame(width: 88, height: 88)
                        }
                    }
                }
            }
        }
    }

    private func loadPhotos() async {
        guard let date else {
            photos = []
            isLoadErrorPresented = false
            return
        }
        do {
            let provider = PhotoSectionsProvider()
            let library = try await provider.loadLibrary()
            let filter = AppliedFilter(kind: .date, value: AppliedFilter.dateText(date))
            photos = await provider.sections(from: library, filters: [filter]).flatMap(\.photos)
            isLoadErrorPresented = false
        } catch {
            photos = []
            isLoadErrorPresented = true
        }
    }
}

private struct DateFilterPhoto: View {
    let localIdentifier: String
    @State private var image: UIImage?

    var body: some View {
        PhotoThumbnail(image: image)
            .task(id: localIdentifier) {
                image = await PhotoThumbnailLoader.shared.thumbnail(
                    for: localIdentifier,
                    targetSize: CGSize(width: 176, height: 176)
                )
            }
    }
}

#Preview {
    DateFilterSheet(date: .constant(Date()), onReset: {}, onDone: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(.black)
}
