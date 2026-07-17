//
//  RootTabView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/6/26.
//

import SwiftUI

struct RootTabView: View {
    @Environment(Router.self) private var router
    let pictureViewModel: PictureViewModel
    let albumViewModel: AlbumViewModel
    let shareViewModel: ShareViewModel
    let selection: NavbarTab

    var body: some View {
        page(for: selection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if showsTopIndicator {
                    MoveInIndicatorBar()
                }
            }
    }

    private var showsTopIndicator: Bool {
        switch selection {
        case .main:
            true
        case .picture:
            !pictureViewModel.isSelectionMode
        case .album:
            !albumViewModel.isSelectionMode
        case .share:
            !shareViewModel.isAddMode
        }
    }

    @ViewBuilder private func page(for tab: NavbarTab) -> some View {
        switch tab {
        case .main:
            MainView()
        case .picture:
            PictureView(
                viewModel: pictureViewModel,
                onOpenFilter: { router.push(.filter) },
                onOpenPhoto: { router.push(.photoDetail($0)) }
            )
        case .album: AlbumView(viewModel: albumViewModel, shareViewModel: shareViewModel)
        case .share: ShareView(viewModel: shareViewModel)
        }
    }
}
