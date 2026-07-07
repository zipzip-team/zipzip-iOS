//
//  PictureView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/5/26.
//

import SwiftUI

struct PictureView: View {
    private let sections: [PhotoSection] = PhotoSection.sample

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 4
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("사진")
                    .font(.t1_sb)
                    .foregroundStyle(.grey900)
                    .frame(height: 44)
                    .padding(.vertical, 4)

                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(sections) { section in
                        photoSection(section)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.orange30.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            floatingButton
        }
    }

    private var floatingButton: some View {
        RoundedIconButton(items: [
            .init(id: "filter", icon: .iconFilter) { /* TODO: 필터 */ },
            .init(id: "selection", icon: .iconSelection) { /* TODO: 선택 모드 */ }
        ])
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func photoSection(_ section: PhotoSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.b2_sb)
                .foregroundStyle(.grey1000)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0 ..< section.count, id: \.self) { _ in
                    Color.grey200
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }
}

private struct PhotoSection: Identifiable {
    let id = UUID()
    let title: String
    let count: Int

    static let sample: [PhotoSection] = [
        PhotoSection(title: "오늘", count: 8),
        PhotoSection(title: "어제", count: 8),
        PhotoSection(title: "7월 1일", count: 8),
        PhotoSection(title: "6월 30일", count: 8)
    ]
}

#Preview {
    PictureView()
}
