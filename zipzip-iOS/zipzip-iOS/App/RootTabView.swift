//
//  RootTabView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/6/26.
//

import SwiftUI

struct RootTabView: View {
    @Environment(Router.self) private var router
    @State private var selection: NavbarTab = .main
    @State private var pictureViewModel = PictureViewModel()
    @State private var albumViewModel = AlbumViewModel()
    @State private var shareViewModel = ShareViewModel()
    @State private var showShareSheet = false

    let albumViewModel: AlbumViewModel

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
            .onChange(of: selection) { _, newValue in
                if newValue != .album {
                    albumViewModel.resetForTabChange()
                    router.removeAlbumRoutes()
                }
                if newValue != .share {
                    shareViewModel.resetTransientUI()
                }
            }
            .bottomSheet(isPresented: $showShareSheet, detents: [.full]) { dismiss in
                ShareSheet(
                    albums: Album.samples,
                    sharedAlbums: Album.sharedSamples,
                    shareAlbums: ShareAlbum.samples,
                    onDismiss: { dismiss() },
                    onComplete: { destinations in
                        let localIdentifiers = pictureViewModel.selectedPhotoLocalIdentifiers
                        Task {
                            guard await albumViewModel.addPhotos(
                                localIdentifiers: localIdentifiers,
                                to: destinations
                            ) else {
                                return
                            }

                            pictureViewModel.cancelSelection()
                            guard let albumID = destinations.firstPersonalAlbumID else {
                                return
                            }

                            selection = .album
                            router.removeAlbumRoutes()
                            router.push(.albumDetail(albumID))
                        }
                    },
                    loadsAlbumsFromDatabase: true
                )
            }
    }

    @ViewBuilder private var bottomBar: some View {
        if selection == .picture, pictureViewModel.isSelectionMode {
            ActionBar(items: [
                .init(
                    icon: .moveToAlbum,
                    title: "집으로",
                    isDisabled: pictureViewModel.selectedPhotoIDs.isEmpty
                ) { showShareSheet = true },
                .init(icon: .metadata, title: "정보 수정") {
                    if let metadata = pictureViewModel.firstSelectedMetadata {
                        router.push(.photoInfoEdit(metadata))
                    }
                },
                .init(icon: .delete, title: "삭제") { pictureViewModel.requestDelete() }
            ])
            .padding(.bottom, 28)
            .ignoresSafeArea(.container, edges: .bottom)
        } else if showsNavbar {
            Navbar(selection: $selection)
                .padding(.bottom, 28)
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    private var showsNavbar: Bool {
        switch selection {
        case .album:
            !albumViewModel.isSelectionMode && !albumViewModel.isDetailPresented
        case .share:
            !shareViewModel.hidesRootNavbar
        default:
            true
        }
    }

    private var content: some View {
        page(for: selection)
    }

    @ViewBuilder private func page(for tab: NavbarTab) -> some View {
        switch tab {
        case .main: MainView()
        case .picture:
            PictureView(
                viewModel: pictureViewModel,
                onOpenFilter: { router.push(.filter) },
                onOpenPhoto: { router.push(.photoDetail($0)) }
            )
        case .album: AlbumView(viewModel: albumViewModel)
        case .share: ShareView(viewModel: shareViewModel)
        }
    }
}
