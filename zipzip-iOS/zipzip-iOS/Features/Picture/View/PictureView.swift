//
//  PictureView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/5/26.
//

import SwiftUI

struct PictureView: View {
    @Environment(Router.self) private var router

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
            .init(id: "filter", icon: .iconFilter) { router.push(.filter) },
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

#Preview {
    PictureView()
        .environment(Router())
}
