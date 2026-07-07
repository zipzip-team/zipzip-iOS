//
//  RootTabView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/6/26.
//

import SwiftUI

struct RootTabView: View {
    @State private var selection: NavbarTab = .main
    @State private var loaded: Set<NavbarTab> = [.main]
    @State private var pictureViewModel = PictureViewModel()

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
    }

    @ViewBuilder private var bottomBar: some View {
        if pictureViewModel.isSelectionMode {
            ActionBar(items: [
                .init(icon: .moveToAlbum, title: "집으로") { /* TODO: */ },
                .init(icon: .metadata, title: "정보 수정") { /* TODO: */ },
                .init(icon: .delete, title: "삭제") { /* TODO: */ }
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
