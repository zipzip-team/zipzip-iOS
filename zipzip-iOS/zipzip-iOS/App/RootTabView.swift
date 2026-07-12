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
    @State private var loaded: Set<NavbarTab> = [.main]
    @State private var pictureViewModel = PictureViewModel()
    @State private var albumViewModel = AlbumViewModel()
    @State private var shareViewModel = ShareViewModel()
    @State private var showShareSheet = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
            .onChange(of: selection) { _, newValue in
                loaded.insert(newValue)
                if newValue != .album {
                    albumViewModel.exitSelectionMode()
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
                    onDismiss: { dismiss() }
                )
            }
    }

    @ViewBuilder private var bottomBar: some View {
        if selection == .picture, pictureViewModel.isSelectionMode {
            ActionBar(items: [
                .init(icon: .moveToAlbum, title: "집으로") { showShareSheet = true },
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
        ZStack {
            ForEach(NavbarTab.allCases, id: \.self) { tab in
                if loaded.contains(tab) {
                    page(for: tab)
                        .opacity(selection == tab ? 1 : 0)
                        .allowsHitTesting(selection == tab)
                        .accessibilityHidden(selection != tab)
                }
            }
        }
    }

    @ViewBuilder private func page(for tab: NavbarTab) -> some View {
        switch tab {
        case .main: MainView()
        case .picture: PictureView(viewModel: pictureViewModel)
        case .album: AlbumView(viewModel: albumViewModel)
        case .share: ShareView(viewModel: shareViewModel)
        }
    }
}
