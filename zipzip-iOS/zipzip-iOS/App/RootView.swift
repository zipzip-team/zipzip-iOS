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
    @State private var photoSync: PhotoSyncCoordinator
    @State private var albumViewModel: AlbumViewModel
    @State private var pictureViewModel = PictureViewModel()
    @State private var shareViewModel: ShareViewModel
    @State private var selection: NavbarTab = .main
    @State private var showShareSheet = false
    @State private var splashAnimationFinished = false
    @State private var hasTriggeredInitialSync = false
    private let makePhotoInfoEditViewModel: ([String]) -> PhotoInfoEditViewModel

    init(
        shareGroupRepository: ShareGroupRepository,
        sharedPhotoRepository: any SharedPhotoRepository,
        makePhotoInfoEditViewModel: @escaping ([String]) -> PhotoInfoEditViewModel
    ) {
        let photoSync = PhotoSyncCoordinator()
        _photoSync = State(initialValue: photoSync)
        _albumViewModel = State(
            initialValue: AlbumViewModel(
                sharedPhotoRepository: sharedPhotoRepository,
                shareGroupRepository: shareGroupRepository,
                photoSync: photoSync
            )
        )
        _shareViewModel = State(
            initialValue: ShareViewModel(
                repository: shareGroupRepository,
                sharedPhotoRepository: sharedPhotoRepository
            )
        )
        self.makePhotoInfoEditViewModel = makePhotoInfoEditViewModel
    }

    var body: some View {
        @Bindable var router = router
        @Bindable var authenticationState = authenticationState
        @Bindable var shareViewModel = shareViewModel
        NavigationStack(path: $router.path) {
            Group {
                if hasCompletedOnboarding {
                    RootTabView(
                        pictureViewModel: pictureViewModel,
                        albumViewModel: albumViewModel,
                        shareViewModel: shareViewModel,
                        selection: selection
                    )
                } else {
                    SplashView {
                        splashAnimationFinished = true
                    }
                }
            }
            .task {
                guard hasCompletedOnboarding else { return }
                if !hasTriggeredInitialSync {
                    hasTriggeredInitialSync = true
                    photoSync.startIfNeeded()
                }
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
                        onMoveAlbumsToPersonal: { sourceAlbums in
                            await albumViewModel.moveSharedAlbumsToPersonalAlbums(sourceAlbums)
                        },
                        onMoveSucceeded: {
                            selectTab(.album)
                        }
                    )
                case let .shareAlbum(groupID, albumID):
                    ShareAlbumDetailDestinationView(
                        groupID: groupID,
                        albumID: albumID,
                        personalAlbums: albumViewModel.shareDestinations,
                        copyPhotosToPersonalAlbums: { photoIDs, sharedAlbumID, personalAlbumIDs in
                            try await albumViewModel.copySharedPhotos(
                                photoIDs: photoIDs,
                                from: sharedAlbumID,
                                to: personalAlbumIDs
                            )
                        },
                        viewModel: shareViewModel
                    )
                case let .sharePhotoDetail(groupID, albumID, photoID):
                    SharedPhotoDetailView(
                        viewModel: shareViewModel.makeSharedPhotoDetailViewModel(
                            groupID: groupID,
                            albumID: albumID,
                            photoID: photoID,
                            onDelete: router.pop
                        )
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
        .overlay {
            if showsRestoreSplash {
                SplashView(continuesOnboarding: false) {
                    splashAnimationFinished = true
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showsRestoreSplash)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
                .animation(.easeInOut(duration: 0.4), value: showsRootTab)
        }
        .bottomSheet(isPresented: $showShareSheet, detents: [.full]) { dismiss in
            ShareSheet(
                albums: albumViewModel.shareDestinations,
                shareAlbums: shareViewModel.groups,
                onDismiss: { dismiss() },
                onOpenShareAlbum: loadSharedAlbums,
                onComplete: { destinations in
                    let localIdentifiers = pictureViewModel.selectedPhotoLocalIdentifiers
                    dismiss()
                    pictureViewModel.cancelSelection()
                    photoSync.track {
                        guard await albumViewModel.addPhotos(
                            localIdentifiers: localIdentifiers,
                            to: destinations
                        ) else {
                            return
                        }

                        guard let albumID = destinations.firstPersonalAlbumID else {
                            return
                        }

                        selectTab(.album, path: [.albumDetail(albumID)])
                    }
                }
            )
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
        .task(id: authenticationState.currentUser?.id) {
            albumViewModel.resetSharedAlbumMoveState()
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

    @ViewBuilder private var bottomBar: some View {
        if showsRootTab, router.path.isEmpty {
            Group {
                if selection == .picture, pictureViewModel.isSelectionMode {
                    ActionBar(items: [
                        .init(
                            icon: .moveToAlbum,
                            title: "집으로",
                            isDisabled: pictureViewModel.selectedPhotoIDs.isEmpty
                        ) { showShareSheet = true },
                        .init(
                            icon: .metadata,
                            title: "정보 수정",
                            isDisabled: pictureViewModel.selectedPhotoIDs.isEmpty
                        ) {
                            if let metadata = pictureViewModel.firstSelectedMetadata {
                                router.push(.photoInfoEdit(PhotoInfoEditDestination(
                                    metadata: metadata,
                                    localIdentifiers: pictureViewModel.selectedPhotoLocalIdentifiers,
                                    onSuccessfulDismiss: pictureViewModel.cancelSelection
                                )))
                            }
                        },
                        .init(
                            icon: .delete,
                            title: "삭제",
                            isDisabled: pictureViewModel.selectedPhotoIDs.isEmpty
                        ) { pictureViewModel.requestDelete() }
                    ])
                    .padding(.bottom, 26.5)
                    .ignoresSafeArea(.container, edges: .bottom)
                } else if showsNavbar {
                    Navbar(selection: selection, onSelect: { selectTab($0) })
                        .padding(.bottom, 28)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
            }
            .transition(.opacity)
        }
    }

    private var showsRootTab: Bool {
        hasCompletedOnboarding && !authenticationState.isRestoring && splashAnimationFinished
    }

    private var showsRestoreSplash: Bool {
        hasCompletedOnboarding && (authenticationState.isRestoring || !splashAnimationFinished)
    }

    private var showsNavbar: Bool {
        switch selection {
        case .album:
            !albumViewModel.isSelectionMode
        case .share:
            !shareViewModel.isAddMode
        default:
            true
        }
    }

    private func loadSharedAlbums(groupID: ShareAlbum.ID) async {
        await shareViewModel.loadSharedAlbums(groupID: groupID)
    }

    private func selectTab(_ newSelection: NavbarTab) {
        selectTab(newSelection, path: [])
    }

    private func selectTab(_ newSelection: NavbarTab, path: [Route]) {
        guard selection != newSelection || router.path != path else {
            return
        }

        if newSelection != .album {
            albumViewModel.resetForTabChange()
        }
        if newSelection != .share {
            shareViewModel.resetTransientUI()
        }

        router.replacePath(with: path)
        selection = newSelection
    }

    private func addPhotosToAlbums(
        localIdentifiers: [String],
        destinations: [ShareDestination]
    ) {
        if destinations.containsSharedAlbum {
            router.popToRoot()
        }
        photoSync.track {
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
        if destinations.containsSharedAlbum {
            router.popToRoot()
        }
        photoSync.track {
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
