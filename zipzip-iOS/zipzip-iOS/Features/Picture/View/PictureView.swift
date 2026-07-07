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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("사진")
                    .font(.t1_sb)
                    .foregroundStyle(.grey900)
                    .frame(height: 44)
                    .padding(.vertical, 4)

                PhotoGallery(sections: sections)
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
}

#Preview {
    PictureView()
        .environment(Router())
}
