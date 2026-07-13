//
//  RootView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/7/26.
//

import AuthenticationServices
import SwiftUI

struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(DIContainer.self) private var container
    @Environment(AuthenticationState.self) private var authenticationState
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var photoSync = PhotoSyncCoordinator()
    @State private var albumViewModel = AlbumViewModel()
    @State private var pictureViewModel = PictureViewModel()

    var body: some View {
        @Bindable var router = router
        @Bindable var authenticationState = authenticationState
        NavigationStack(path: $router.path) {
            Group {
                if authenticationState.isRestoring, hasCompletedOnboarding {
                    SplashView(continuesOnboarding: false)
                } else if hasCompletedOnboarding {
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
            .onChange(of: scenePhase) { _, newPhase in
                guard hasCompletedOnboarding, newPhase == .active else { return }
                photoSync.refresh()
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
                case let .photoInfoEdit(metadata, localIdentifiers):
                    PhotoInfoEditView(metadata: metadata, localIdentifiers: localIdentifiers)
                case let .photoDetail(photo):
                    PhotoDetailView(
                        photo: photo,
                        albums: albumViewModel.shareDestinations,
                        onDelete: { action, currentPhoto in
                            guard action == .deletePermanently else { return false }
                            return await pictureViewModel.deletePhotos(
                                localIdentifiers: [currentPhoto.localIdentifier]
                            )
                        },
                        onAddToAlbums: addPhotosToAlbums,
                        loadIsFavorite: { await albumViewModel.isPhotoFavorited(localIdentifier: $0) },
                        onToggleFavorite: togglePhotoFavorite
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
                        onDelete: { action, currentPhoto in
                            await albumViewModel.deletePhotos([currentPhoto.id], from: albumID, action: action)
                        },
                        onAddToAlbums: addPhotosToAlbums,
                        onMoveToAlbums: { albumPhotoIDs, destinations in
                            moveAlbumPhotosToAlbums(
                                ids: albumPhotoIDs,
                                from: albumID,
                                destinations: destinations
                            )
                        },
                        loadIsFavorite: { await albumViewModel.isPhotoFavorited(localIdentifier: $0) },
                        onToggleFavorite: togglePhotoFavorite
                    )
                case .myPage:
                    MyPageView()
                case .registeredDeviceManagement:
                    RegisteredDeviceManagementView(store: container.registeredDeviceStore)
                }
            }
        }
        .environment(photoSync)
        .fullScreenCover(item: $authenticationState.loginIntent) { _ in
            ShareLoginView()
        }
        .task {
            await authenticationState.restore(
                minimumDuration: hasCompletedOnboarding ? .seconds(2) : .zero
            )
            await authenticationState.checkAppleCredentialState()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await authenticationState.checkAppleCredentialState() }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: ASAuthorizationAppleIDProvider.credentialRevokedNotification
            )
        ) { _ in
            Task { await authenticationState.handleAppleCredentialRevocation() }
        }
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

    private func togglePhotoFavorite(localIdentifier: String, isFavorite: Bool) {
        albumViewModel.setPhotoFavorite(
            localIdentifier: localIdentifier,
            isFavorite: isFavorite
        )
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
