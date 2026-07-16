//
//  AlbumShareMoveLoadingView.swift
//  zipzip-iOS
//

import SwiftUI

struct AlbumShareMoveLoadingView: View {
    @Environment(Router.self) private var router

    let groupID: ShareAlbum.ID
    let albumViewModel: AlbumViewModel
    let shareViewModel: ShareViewModel

    @State private var hasStarted = false

    var body: some View {
        Color.orange30
            .ignoresSafeArea()
            .overlay {
                ProgressView()
                    .tint(.orange500)
            }
            .navigationBarBackButtonHidden(true)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .task(id: groupID) {
                guard !hasStarted else { return }
                hasStarted = true
                await moveAlbums()
            }
    }

    private func moveAlbums() async {
        if shareViewModel.group(withID: groupID) == nil {
            await shareViewModel.loadGroup(id: groupID)
        }
        guard let group = shareViewModel.group(withID: groupID) else {
            router.pop()
            return
        }

        let didComplete = await albumViewModel.completeShareAlbumMove(to: group)
        guard !Task.isCancelled else { return }
        guard didComplete else {
            router.pop()
            return
        }

        await shareViewModel.loadGroup(id: groupID)
        await shareViewModel.loadSharedAlbums(groupID: groupID)
        guard !Task.isCancelled else { return }
        router.replacePath(with: [.shareGroup(groupID)])
    }
}
