//
//  FilteredPictureView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct FilteredPictureView: View {
    @Environment(Router.self) private var router

    let appliedFilters: [String]

    private let sections: [PhotoSection] = PhotoSection.sample

    var body: some View {
        VStack(spacing: 8) {
            topBar
            ScrollView {
                PhotoGallery(sections: sections)
                    .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.orange30.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .bottom) {
            filterChipBar
        }
    }

    private var topBar: some View {
        HStack {
            RoundedIconButton(items: [
                .init(id: "back", icon: .iconChevronLeft) { router.pop() }
            ])
            Spacer()
            RoundedIconButton(items: [
                .init(id: "selection", icon: .iconSelection) { /* TODO: 선택 모드 */ }
            ])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var filterChipBar: some View {
        HStack(spacing: 10) {
            ForEach(appliedFilters, id: \.self) { filter in
                AppliedFilterChip(title: filter)
            }
            AddFilterChip { router.pop() }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

#Preview {
    FilteredPictureView(appliedFilters: ["iphone 6", "오사카"])
        .environment(Router())
}
