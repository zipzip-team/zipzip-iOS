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

    @State private var isEditingInfo = false
    @State private var showShareSheet = false

    private let photoPeekHeight: CGFloat = 160

    var body: some View {
        GeometryReader { geo in
            let reveal = max(geo.size.height - photoPeekHeight, 0)

            VStack(spacing: 0) {
                Color.grey200
                    .frame(width: geo.size.width, height: geo.size.height)

                ScrollView {
                    PhotoInfoEditContent(metadata: photo.metadata)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: geo.size.width, height: reveal)
            }
            .offset(y: isEditingInfo ? -reveal : 0)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .clipped()
            .animation(.easeInOut(duration: 0.3), value: isEditingInfo)
        }
        .background(Color.orange30.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .topLeading) {
            backButton
        }
        .overlay(alignment: .bottom) {
            if !isEditingInfo {
                actionBar.transition(.opacity)
            }
        }
        .bottomSheet(isPresented: $showShareSheet, detents: [.full]) { dismiss in
            ShareSheet(
                albums: Album.samples,
                sharedAlbums: Album.sharedSamples,
                shareAlbums: ShareAlbum.samples,
                onDismiss: { dismiss() }
            )
        }
    }

    private var backButton: some View {
        RoundedIconButton(items: [
            .init(id: "back", icon: .iconChevronLeft) {
                if isEditingInfo {
                    withAnimation { isEditingInfo = false }
                } else {
                    router.pop()
                }
            }
        ])
        .opacity(0.9)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var actionBar: some View {
        ActionBar(items: [
            .init(icon: .starStroke, title: "즐겨찾기") { /* TODO: 즐겨찾기 */ },
            .init(icon: .moveToAlbum, title: "집으로") { showShareSheet = true },
            .init(icon: .metadata, title: "정보 수정") {
                withAnimation { isEditingInfo = true }
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
