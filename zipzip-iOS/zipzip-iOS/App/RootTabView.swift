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
    @State private var showShareSheet = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
                    .padding(.bottom, 28)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
            .onChange(of: selection) { _, newValue in
                loaded.insert(newValue)
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
        if pictureViewModel.isSelectionMode {
            ActionBar(items: [
                .init(icon: .moveToAlbum, title: "집으로") { showShareSheet = true },
                .init(icon: .metadata, title: "정보 수정") {
                    if let metadata = pictureViewModel.firstSelectedMetadata {
                        router.push(.photoInfoEdit(metadata))
                    }
                },
                .init(icon: .delete, title: "삭제") { pictureViewModel.requestDelete() }
            ])
        } else {
            Navbar(selection: $selection)
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
        case .album: AlbumView()
        case .share: ShareView()
        }
    }
}
