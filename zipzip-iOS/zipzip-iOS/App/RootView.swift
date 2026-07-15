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
    @State private var shareViewModel: ShareViewModel
    private let makePhotoInfoEditViewModel: ([String]) -> PhotoInfoEditViewModel

    init(
        shareGroupRepository: ShareGroupRepository,
        makePhotoInfoEditViewModel: @escaping ([String]) -> PhotoInfoEditViewModel
    ) {
        _shareViewModel = State(
            initialValue: ShareViewModel(repository: shareGroupRepository)
        )
        self.makePhotoInfoEditViewModel = makePhotoInfoEditViewModel
    }

    var body: some View {
        @Bindable var router = router
        @Bindable var authenticationState = authenticationState
        @Bindable var shareViewModel = shareViewModel
        NavigationStack(path: $router.path) {
            Group {
                if authenticationState.isRestoring, hasCompletedOnboarding {
                    SplashView(continuesOnboarding: false)
                } else if hasCompletedOnboarding {
                    RootTabView(
                        albumViewModel: albumViewModel,
                        pictureViewModel: pictureViewModel,
                        shareViewModel: shareViewModel
                    )
                } else {
                    SplashView()
                }
            }
            .task {
                KeyboardPrewarmer.prewarm()
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
                        albumViewModel: albumViewModel,
                        shareViewModel: shareViewModel
                    )
                case let .photoInfoEdit(destination):
                    PhotoInfoEditView(
                        metadata: destination.metadata,
                        viewModel: makePhotoInfoEditViewModel(destination.localIdentifiers),
                        onSuccessfulDismiss: destination.completeSuccessfulEdit
                    )
                case let .photoDetail(photo):
                    PhotoDetailView(
                        photo: photo,
                        albums: albumViewModel.shareDestinations,
                        shareViewModel: shareViewModel,
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
                        shareViewModel: shareViewModel,
                        albumID: albumID
                    )
                case let .albumPhotoDetail(albumID, photo):
                    PhotoDetailView(
                        photo: photo,
                        albums: albumViewModel.shareDestinations,
                        shareViewModel: shareViewModel,
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
                case let .shareGroup(groupID):
                    ShareGroupDetailView(
                        groupID: groupID,
                        viewModel: shareViewModel,
                        personalAlbums: albumViewModel.shareDestinations
                    )
                case let .shareAlbum(groupID, albumID):
                    ShareAlbumDetailDestinationView(
                        groupID: groupID,
                        albumID: albumID,
                        viewModel: shareViewModel
                    )
                case let .shareImport(groupID):
                    ShareImportView(
                        groupID: groupID,
                        viewModel: shareViewModel,
                        albums: albumViewModel.shareDestinations,
                        photoSections: pictureViewModel.sections
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
        .alert("요청을 완료하지 못했어요", isPresented: $shareViewModel.isErrorAlertPresented) {
            if shareViewModel.canRetryError {
                Button("다시 시도") {
                    Task { await shareViewModel.retryErrorAction() }
                }
            }
            Button("확인", role: .cancel, action: shareViewModel.dismissErrorAlert)
        } message: {
            Text(shareViewModel.errorAlertMessage)
        }
        .alert("요청을 완료하지 못했어요", isPresented: $albumViewModel.isErrorAlertPresented) {
            if albumViewModel.canRetryError {
                Button("다시 시도") {
                    Task { await albumViewModel.retryErrorAction() }
                }
            }
            Button("확인", role: .cancel, action: albumViewModel.dismissErrorAlert)
        } message: {
            Text(albumViewModel.errorAlertMessage)
        }
        .task {
            await authenticationState.restore(
                minimumDuration: hasCompletedOnboarding ? .seconds(2) : .zero
            )
            await authenticationState.checkAppleCredentialState()
        }
        .task(id: authenticationState.currentUser?.id) {
            if let userID = authenticationState.currentUser?.id {
                await shareViewModel.loadGroups(for: userID)
            } else {
                shareViewModel.resetRemoteData()
            }
        }
        .task(id: authenticationState.currentUser?.id) {
            if let user = authenticationState.currentUser {
                await container.userProfileState.load(for: user)
            } else {
                container.userProfileState.reset()
            }
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

    private func togglePhotoFavorite(localIdentifier: String, isFavorite: Bool) async -> Bool {
        await albumViewModel.setPhotoFavorite(
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
