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

extension Array where Element == ShareDestination {
    var firstPersonalAlbumID: Album.ID? {
        for destination in self {
            if case let .album(albumID) = destination {
                return albumID
            }
        }
        return nil
    }
}

struct ShareSheet: View {
    @Environment(AuthenticationState.self) private var authenticationState

    let albums: [Album]
    let sharedAlbums: [Album]
    let shareAlbums: [ShareAlbum]
    let onDismiss: () -> Void
    var excludedAlbumIDs: Set<Album.ID> = []
    /// 완료 시 선택 순서대로 전달한다. 호출 화면은 사진 추가, 이동 등 필요한 동작을 결정한다.
    var onComplete: ([ShareDestination]) -> Void = { _ in }
    var loadsAlbumsFromDatabase = false

    @State private var selection: BottomSheetTabSelection = .left
    @State private var selectedAlbumIDs: [Album.ID] = []
    @State private var targetShareAlbum: ShareAlbum?
    @State private var fetchedAlbums: [Album]?

    private let albumStore = AlbumStore()

    var body: some View {
        BottomSheet(
            middleItem: .init(leftField: "사진집", rightField: "공유", selection: $selection),
            leftItem: {
                leadingHeaderButton
            },
            rightItem: {
                if showsCompletionButton {
                    headerButton("완료", isDisabled: selectedDestinations.isEmpty, action: completeSelection)
                }
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
            selectedAlbumIDs = []
        }
        .task {
            await loadAlbumsIfNeeded()
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
                albums: personalAlbums,
                selectedAlbumIDs: selectedAlbumIDs,
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
                    selectedAlbumIDs: selectedAlbumIDs,
                    onSelect: selectAlbum
                )
            } else {
                ShareAlbumList(albums: shareAlbums) { album in
                    targetShareAlbum = album
                    selectedAlbumIDs = []
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
        .disabled(isDisabled)
        .accessibilityHint(isDisabled ? "대상을 선택하면 완료할 수 있습니다." : "")
    }

    private func selectAlbum(_ album: Album) {
        if let index = selectedAlbumIDs.firstIndex(of: album.id) {
            selectedAlbumIDs.remove(at: index)
        } else {
            selectedAlbumIDs.append(album.id)
        }
    }

    private var showsCompletionButton: Bool {
        selection == .left || authenticationState.isLoggedIn
    }

    private var personalAlbums: [Album] {
        (fetchedAlbums ?? albums).filter { !excludedAlbumIDs.contains($0.id) }
    }

    @MainActor
    private func loadAlbumsIfNeeded() async {
        guard loadsAlbumsFromDatabase,
              let storedAlbums = try? await albumStore.fetchAlbums()
        else {
            return
        }

        fetchedAlbums = storedAlbums.map {
            Album(
                id: $0.id,
                name: $0.name,
                count: $0.photoCount,
                thumbnailLocalIdentifiers: $0.thumbnailLocalIdentifiers
            )
        }
    }

    private var selectedDestinations: [ShareDestination] {
        switch selection {
        case .left:
            return selectedAlbumIDs.map(ShareDestination.album)
        case .right:
            guard let targetShareAlbum else {
                return []
            }
            return selectedAlbumIDs.map {
                .sharedAlbum(shareAlbumID: targetShareAlbum.id, albumID: $0)
            }
        }
    }

    private func completeSelection() {
        guard !selectedDestinations.isEmpty else {
            return
        }

        onComplete(selectedDestinations)
        onDismiss()
    }

    private func returnToShareAlbumList() {
        targetShareAlbum = nil
        selectedAlbumIDs = []
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
    let selectedAlbumIDs: [Album.ID]
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
                            state: selectedAlbumIDs.contains(album.id) ? .highlighted : .plain,
                            nameColorOverride: .white00,
                            thumbnailLocalIdentifiers: album.thumbnailLocalIdentifiers
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
