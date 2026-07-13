//
//  Route.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Foundation

enum Route: Hashable {
    case splash
    case serviceIntro
    case onboardingComplete
    case photoPermission
    case deviceLoading
    case deviceSelection
    case filter
    case filterResult([AppliedFilter])
    case photoInfoEdit(metadata: PhotoMetadata, localIdentifiers: [String])
    case photoDetail(Photo)
    case albumDetail(Int)
    case albumPhotoDetail(albumID: Int, photo: Photo)
    case myPage
    case registeredDeviceManagement

    var isAlbumRoute: Bool {
        switch self {
        case .albumDetail, .albumPhotoDetail:
            true
        default:
            false
        }
    }
}
