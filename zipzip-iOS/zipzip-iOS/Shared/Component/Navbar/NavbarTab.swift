//
//  NavbarTab.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/6/26.
//

import SwiftUI

enum NavbarTab: CaseIterable {
    case main, picture, album, share

    var title: String {
        switch self {
        case .main: "메인"
        case .picture: "사진"
        case .album: "앨범"
        case .share: "공유"
        }
    }

    var selectedIcon: ImageResource {
        switch self {
        case .main: .navMainSelected
        case .picture: .navPictureSelected
        case .album: .navAlbumSelected
        case .share: .navShareSelected
        }
    }

    var unselectedIcon: ImageResource {
        switch self {
        case .main: .navMainUnselected
        case .picture: .navPictureUnselected
        case .album: .navAlbumUnselected
        case .share: .navShareUnselected
        }
    }
}
