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

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Navbar(selection: $selection)
                    .padding(.bottom, 28)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
            .onChange(of: selection) { _, newValue in
                loaded.insert(newValue)
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
        case .picture: PictureView()
        case .album: AlbumView()
        case .share: ShareView()
        }
    }
}
