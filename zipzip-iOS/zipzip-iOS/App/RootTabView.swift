//
//  RootTabView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/6/26.
//

import SwiftUI

struct RootTabView: View {
    @State private var selection: NavbarTab = .main

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Navbar(selection: $selection)
                    .padding(.bottom, 28)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
    }

    @ViewBuilder private var content: some View {
        switch selection {
        case .main: MainView()
        case .picture: PictureView()
        case .album: AlbumView()
        case .share: ShareView()
        }
    }
}
