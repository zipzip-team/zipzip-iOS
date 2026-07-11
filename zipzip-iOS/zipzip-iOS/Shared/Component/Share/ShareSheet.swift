//
//  ShareSheet.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

enum ShareDestination: Hashable {
    case album(Album.ID)
    case sharedAlbum(shareAlbumID: ShareAlbum.ID, albumID: Album.ID)
}

struct ShareSheet: View {
    @Environment(AuthenticationState.self) private var authenticationState

    let albums: [Album]
    let sharedAlbums: [Album]
    let shareAlbums: [ShareAlbum]
    let onDismiss: () -> Void
    var onComplete: (ShareDestination) -> Void = { _ in }

    @State private var selection: BottomSheetTabSelection = .left
    @State private var selectedAlbumID: Album.ID?
    @State private var targetShareAlbum: ShareAlbum?

    var body: some View {
        BottomSheet(
            middleItem: .init(leftField: "사진집", rightField: "공유", selection: $selection),
            leftItem: {
                headerButton("취소") { onDismiss() }
            },
            rightItem: {
                if showsCompletionButton {
                    headerButton("완료", isDisabled: selectedDestination == nil, action: completeSelection)
                }
            }
        ) {
            content
        }
        .onChange(of: selection) { _, _ in
            targetShareAlbum = nil
            selectedAlbumID = nil
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
            if !authenticationState.isLoggedIn {
                ShareLoginPrompt {
                    authenticationState.logIn()
                }
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

    private func headerButton(
        _ title: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.b1_sb)
                .foregroundStyle(isDisabled ? .grey700 : .white00)
                .frame(width: 72, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func selectAlbum(_ album: Album) {
        selectedAlbumID = album.id
    }

    private var showsCompletionButton: Bool {
        selection == .left || authenticationState.isLoggedIn
    }

    private var selectedDestination: ShareDestination? {
        guard let selectedAlbumID else {
            return nil
        }

        switch selection {
        case .left:
            return .album(selectedAlbumID)
        case .right:
            guard let targetShareAlbum else {
                return nil
            }
            return .sharedAlbum(shareAlbumID: targetShareAlbum.id, albumID: selectedAlbumID)
        }
    }

    private func completeSelection() {
        guard let selectedDestination else {
            return
        }

        onComplete(selectedDestination)
        onDismiss()
    }
}

struct ShareLoginPrompt: View {
    let onLogin: () -> Void

    var body: some View {
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

            CommonButton(title: "로그인", property1: .cta, action: onLogin)
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
                    .buttonStyle(StaticButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 28)
            .transaction { transaction in
                transaction.animation = nil
            }
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
    .environment(AuthenticationState())
}
