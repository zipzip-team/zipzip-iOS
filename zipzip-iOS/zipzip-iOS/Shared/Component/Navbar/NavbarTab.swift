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
        case .album: "사진집"
        case .share: "공유"
        }
    }

    var icon: ImageResource {
        switch self {
        case .main: .main
        case .picture: .photo
        case .album: .album
        case .share: .share
        }
    }
}
