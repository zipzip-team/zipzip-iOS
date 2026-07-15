//
//  ShareSheet.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

enum ShareDestination: Hashable {
    case album(Album.ID)
    case sharedAlbum(shareAlbumID: ShareAlbum.ID, albumID: SharedAlbum.ID)
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
    let shareAlbums: [ShareAlbum]
    let onDismiss: () -> Void
    var excludedAlbumIDs: Set<Album.ID> = []
    var onOpenShareAlbum: (ShareAlbum.ID) async -> Void = { _ in }
    /// 완료 시 선택 순서대로 전달한다. 호출 화면은 사진 추가, 이동 등 필요한 동작을 결정한다.
    var onComplete: ([ShareDestination]) -> Void = { _ in }

    @State private var selection: BottomSheetTabSelection = .left
    @State private var selectedAlbumIDs: [Album.ID] = []
    @State private var selectedSharedAlbumIDs: [SharedAlbum.ID] = []
    @State private var targetShareAlbumID: ShareAlbum.ID?

    var body: some View {
        BottomSheet(
            middleItem: .init(leftField: "사진집", rightField: "공유", selection: $selection),
            leftItem: {
                leadingHeaderButton
            },
            rightItem: {
                if showsCompletionButton {
                    headerButton("완료", isDisabled: isCompletionDisabled, action: completeSelection)
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
            targetShareAlbumID = nil
            selectedAlbumIDs = []
            selectedSharedAlbumIDs = []
        }
        .task(id: targetShareAlbumID) {
            guard let targetShareAlbumID else { return }
            await onOpenShareAlbum(targetShareAlbumID)
        }
    }

    @ViewBuilder private var leadingHeaderButton: some View {
        if targetShareAlbumID != nil {
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
                    authenticationState.requestLogin(.share)
                }
            } else if let targetShareAlbum {
                SharedAlbumSelectionGrid(
                    albums: targetShareAlbum.albums,
                    selectedAlbumIDs: selectedSharedAlbumIDs,
                    onSelect: selectSharedAlbum
                )
            } else {
                ShareAlbumList(albums: shareAlbums) { album in
                    targetShareAlbumID = album.id
                    selectedAlbumIDs = []
                    selectedSharedAlbumIDs = []
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

    private func selectSharedAlbum(_ album: SharedAlbum) {
        if let index = selectedSharedAlbumIDs.firstIndex(of: album.id) {
            selectedSharedAlbumIDs.remove(at: index)
        } else {
            selectedSharedAlbumIDs.append(album.id)
        }
    }

    private var showsCompletionButton: Bool {
        selection == .left || authenticationState.isLoggedIn
    }

    private var isCompletionDisabled: Bool {
        // TODO: 정교은 담당 photos/attach API가 합쳐지면 공유 탭에서도 선택 완료를 허용하고,
        // 호출 화면에서 선택한 server photo id와 shared album id를 attach한 뒤 목록을 갱신합니다.
        selection == .right || selectedDestinations.isEmpty
    }

    private var personalAlbums: [Album] {
        albums.filter { !excludedAlbumIDs.contains($0.id) }
    }

    private var selectedDestinations: [ShareDestination] {
        switch selection {
        case .left:
            return selectedAlbumIDs.map(ShareDestination.album)
        case .right:
            guard let targetShareAlbum else {
                return []
            }
            return selectedSharedAlbumIDs.map {
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
        targetShareAlbumID = nil
        selectedAlbumIDs = []
        selectedSharedAlbumIDs = []
    }

    private var targetShareAlbum: ShareAlbum? {
        shareAlbums.first { $0.id == targetShareAlbumID }
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

private struct SharedAlbumSelectionGrid: View {
    let albums: [SharedAlbum]
    let selectedAlbumIDs: [SharedAlbum.ID]
    let onSelect: (SharedAlbum) -> Void

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

#if DEBUG
    #Preview {
        ShareSheet(
            albums: Album.samples,
            shareAlbums: [],
            onDismiss: {}
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(.black)
        .environment(AuthenticationState.preview())
    }
#endif
