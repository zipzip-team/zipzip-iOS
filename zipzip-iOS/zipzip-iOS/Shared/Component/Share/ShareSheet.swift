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
                leadingHeaderButton
            },
            rightItem: {
                headerButton("완료", isDisabled: selectedDestination == nil, action: completeSelection)
            }
        ) {
            content
                .scrollIndicators(.hidden)
                .transaction { transaction in
                    transaction.disablesAnimations = true
                    transaction.animation = nil
                }
        }
        .onChange(of: selection) { _, _ in
            targetShareAlbum = nil
            selectedAlbumID = nil
        }
    }

    @ViewBuilder private var leadingHeaderButton: some View {
        if targetShareAlbum != nil {
            BottomSheetBackButton(action: returnToShareAlbumList)
        } else {
            BottomSheetCloseButton(action: onDismiss)
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
                .foregroundStyle(.white00)
                .frame(width: 72, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isDisabled ? "대상을 선택하면 완료할 수 있습니다." : "")
    }

    private func selectAlbum(_ album: Album) {
        selectedAlbumID = album.id
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

    private func returnToShareAlbumList() {
        targetShareAlbum = nil
        selectedAlbumID = nil
    }
}

struct ShareLoginPrompt: View {
    let onLogin: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Color.grey200
                    .frame(width: 80, height: 80)

                Image(.shareLoginRequired)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 234, height: 54)
                    .accessibilityLabel("공유 폴더는 집에 대한 소개가 필요해요.")
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
        ScrollView(showsIndicators: false) {
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
    var selectedShareAlbumID: ShareAlbum.ID? = nil
    var showsChevron = true
    let onSelect: (ShareAlbum) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(albums) { album in
                    Button {
                        onSelect(album)
                    } label: {
                        ShareDestinationRow(
                            album: album,
                            isSelected: selectedShareAlbumID == album.id,
                            showsChevron: showsChevron
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

private struct ShareDestinationRow: View {
    let album: ShareAlbum
    let isSelected: Bool
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 16) {
                Color.grey100
                    .frame(width: 72, height: 72)
                    .clipShape(.rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 0) {
                    Text(album.name)
                        .font(.t3_sb)
                        .foregroundStyle(.grey1000)
                        .lineLimit(1)

                    Text("\(album.memberCount)명")
                        .font(.b2_md)
                        .foregroundStyle(.grey700)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsChevron {
                Image(.chevronRight)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.grey1000)
                    .frame(width: 24, height: 24)
                    .frame(width: 40, height: 40)
            } else {
                Color.clear
                    .frame(width: 40, height: 40)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? .orange50 : .grey50, in: .rect(cornerRadius: 12))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.orange300, lineWidth: 1)
            }
        }
        .contentShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(album.name), \(album.memberCount)명")
        .accessibilityValue(isSelected ? "선택됨" : "")
        .accessibilityHint(showsChevron ? "공유집 열기" : "공유집 선택")
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
