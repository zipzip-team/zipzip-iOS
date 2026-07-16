//
//  Route.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Foundation

struct PhotoInfoEditDestination: Hashable {
    let id: UUID
    let metadata: PhotoMetadata
    let localIdentifiers: [String]

    private let onSuccessfulDismiss: () -> Void

    init(
        id: UUID = UUID(),
        metadata: PhotoMetadata,
        localIdentifiers: [String],
        onSuccessfulDismiss: @escaping () -> Void = {}
    ) {
        self.id = id
        self.metadata = metadata
        self.localIdentifiers = localIdentifiers
        self.onSuccessfulDismiss = onSuccessfulDismiss
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func completeSuccessfulEdit() {
        onSuccessfulDismiss()
    }
}

enum Route: Hashable {
    case splash
    case serviceIntro
    case onboardingComplete
    case photoPermission
    case deviceLoading
    case deviceSelection
    case filter
    case filterResult([AppliedFilter])
    case photoInfoEdit(PhotoInfoEditDestination)
    case photoDetail(Photo)
    case albumDetail(Int)
    case albumPhotoDetail(albumID: Int, photo: Photo)
    case shareGroup(UUID)
    case shareAlbum(groupID: UUID, albumID: UUID)
    case sharePhotoDetail(groupID: UUID, albumID: UUID, photoID: UUID)
    case shareImport(UUID)
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

    var isShareRoute: Bool {
        switch self {
        case .shareGroup, .shareAlbum, .sharePhotoDetail, .shareImport:
            true
        default:
            false
        }
    }
}
