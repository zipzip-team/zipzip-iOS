//
//  ShareSheet.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct ShareSheet: View {
    let albums: [Album]
    let sharedAlbums: [Album]
    let shareAlbums: [ShareAlbum]
    let onDismiss: () -> Void

    @State private var selection: BottomSheetTabSelection = .left
    @State private var isLoggedIn = false
    @State private var selectedAlbumID: Album.ID?
    @State private var targetShareAlbum: ShareAlbum?

    var body: some View {
        BottomSheet(
            middleItem: .init(leftField: "사진집", rightField: "공유", selection: $selection),
            leftItem: {
                headerButton("취소") { onDismiss() }
            },
            rightItem: {
                headerButton("완료") { onDismiss() } // TODO: 실제 저장 연동
            }
        ) {
            content
        }
        .onChange(of: selection) { _, _ in
            targetShareAlbum = nil
        }
    }

    @ViewBuilder private var content: some View {
        switch selection {
        case .left:
            AlbumSelectionGrid(
                albums: albums,
                selectedAlbumID: selectedAlbumID,
                onSelect: selectAlbum
            )
        case .right:
            if !isLoggedIn {
                loginPrompt
            } else if targetShareAlbum != nil {
                AlbumSelectionGrid(
                    albums: sharedAlbums,
                    selectedAlbumID: selectedAlbumID,
                    onSelect: selectAlbum
                )
            } else {
                ShareAlbumList(albums: shareAlbums) { album in
                    targetShareAlbum = album
                    selectedAlbumID = nil
                }
            }
        }
    }

    private func headerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.b1_sb)
                .foregroundStyle(.white00)
                .frame(width: 72, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectAlbum(_ album: Album) {
        selectedAlbumID = album.id
    }

    private var loginPrompt: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Color.grey200
                    .frame(width: 80, height: 80)

                // TODO: 커스텀 폰트 텍스트를 SVG 에셋으로 교체
                Text("공유 폴더는\n집에 대한 소개가 필요해요.")
                    .font(.b1_md)
                    .foregroundStyle(.white00)
                    .multilineTextAlignment(.center)
            }

            CommonButton(title: "로그인", property1: .cta) {
                isLoggedIn = true
            }
            .frame(width: 171)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

struct AlbumSelectionGrid: View {
    let albums: [Album]
    let selectedAlbumID: Album.ID?
    let onSelect: (Album) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 17),
        GridItem(.flexible(), spacing: 17)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(albums) { album in
                    Button {
                        onSelect(album)
                    } label: {
                        AlbumCard(
                            name: album.name,
                            count: album.count,
                            state: selectedAlbumID == album.id ? .highlighted : .plain,
                            nameColorOverride: .white00
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 28)
        }
    }
}

struct ShareAlbumList: View {
    let albums: [ShareAlbum]
    let onSelect: (ShareAlbum) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(albums) { album in
                    Button {
                        onSelect(album)
                    } label: {
                        ShareAlbumCard(
                            thumbnail: nil,
                            title: album.name,
                            date: album.date,
                            profileImages: [Image?](repeating: nil, count: 4),
                            memberCount: album.memberCount
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 28)
        }
    }
}

#Preview {
    ShareSheet(
        albums: Album.samples,
        sharedAlbums: Album.sharedSamples,
        shareAlbums: ShareAlbum.samples,
        onDismiss: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(.black)
}
