//
//  RootView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/7/26.
//

import SwiftUI

struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(DIContainer.self) private var container
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var photoSync = PhotoSyncCoordinator()
    @State private var albumViewModel = AlbumViewModel()
    @State private var pictureViewModel = PictureViewModel()

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            Group {
                if hasCompletedOnboarding {
                    RootTabView(albumViewModel: albumViewModel, pictureViewModel: pictureViewModel)
                } else {
                    SplashView()
                }
            }
            .task {
                guard hasCompletedOnboarding else { return }
                photoSync.startIfNeeded()
                await albumViewModel.loadAlbums()
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .splash:
                    SplashView()
                case .serviceIntro:
                    ServiceIntroView()
                case .onboardingComplete:
                    OnboardingCompleteView()
                case .photoPermission:
                    PhotoPermissionView()
                case .deviceLoading:
                    DeviceLoadingView()
                case .deviceSelection:
                    DeviceSelectionView(store: container.registeredDeviceStore)
                case .filter:
                    FilterView()
                case let .filterResult(filters):
                    FilteredPictureView(
                        appliedFilters: filters,
                        albumViewModel: albumViewModel
                    )
                case let .photoInfoEdit(metadata):
                    PhotoInfoEditView(metadata: metadata)
                case let .photoDetail(photo):
                    PhotoDetailView(
                        photo: photo,
                        albums: albumViewModel.shareDestinations,
                        onDelete: { action in
                            guard action == .deletePermanently else { return false }
                            return await pictureViewModel.deletePhotos(
                                localIdentifiers: [photo.localIdentifier]
                            )
                        },
                        onAddToAlbums: addPhotosToAlbums
                    )
                case let .albumDetail(albumID):
                    AlbumDetailDestinationView(
                        viewModel: albumViewModel,
                        albumID: albumID
                    )
                case let .albumPhotoDetail(albumID, photo):
                    PhotoDetailView(
                        photo: photo,
                        albums: albumViewModel.shareDestinations,
                        deletionContext: .album,
                        excludedAlbumIDs: [albumID],
                        onDelete: { action in
                            albumViewModel.deletePhotos([photo.id], from: albumID, action: action)
                            return true
                        },
                        onAddToAlbums: addPhotosToAlbums,
                        onMoveToAlbums: { albumPhotoIDs, destinations in
                            moveAlbumPhotosToAlbums(
                                ids: albumPhotoIDs,
                                from: albumID,
                                destinations: destinations
                            )
                        }
                    )
                case .myPage:
                    MyPageView()
                case .registeredDeviceManagement:
                    RegisteredDeviceManagementView(store: container.registeredDeviceStore)
                }
            }
        }
        .environment(photoSync)
    }

    private func addPhotosToAlbums(
        localIdentifiers: [String],
        destinations: [ShareDestination]
    ) {
        Task {
            guard await albumViewModel.addPhotos(
                localIdentifiers: localIdentifiers,
                to: destinations
            ) else {
                return
            }

            guard let albumID = destinations.firstPersonalAlbumID else {
                return
            }

            router.push(.albumDetail(albumID))
        }
    }

    private func moveAlbumPhotosToAlbums(
        ids: [Int],
        from sourceAlbumID: Album.ID,
        destinations: [ShareDestination]
    ) {
        Task {
            guard await albumViewModel.moveAlbumPhotos(
                ids: ids,
                from: sourceAlbumID,
                to: destinations
            ), let albumID = destinations.firstPersonalAlbumID
            else {
                return
            }

            router.push(.albumDetail(albumID))
        }
    }
}
