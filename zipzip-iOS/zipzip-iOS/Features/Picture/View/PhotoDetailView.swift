//
//  PhotoDetailView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct PhotoDetailView: View {
    @Environment(Router.self) private var router

    let photo: Photo

    var body: some View {
        Color.grey200
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.orange30.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .overlay(alignment: .topLeading) {
                backButton
            }
            .overlay(alignment: .bottom) {
                actionBar
            }
    }

    private var backButton: some View {
        RoundedIconButton(items: [
            .init(id: "back", icon: .iconChevronLeft) { router.pop() }
        ])
        .opacity(0.9)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var actionBar: some View {
        ActionBar(items: [
            .init(icon: .starStroke, title: "즐겨찾기") { /* TODO: 즐겨찾기 */ },
            .init(icon: .moveToAlbum, title: "집으로") { /* TODO: 집으로 */ },
            .init(icon: .metadata, title: "정보 수정") {
                router.push(.photoInfoEdit(photo.metadata))
            },
            .init(icon: .delete, title: "삭제") { /* TODO: 삭제 */ }
        ])
        .padding(.bottom, 16)
    }
}

#Preview {
    PhotoDetailView(photo: PhotoSection.sample[0].photos[0])
        .environment(Router())
}
