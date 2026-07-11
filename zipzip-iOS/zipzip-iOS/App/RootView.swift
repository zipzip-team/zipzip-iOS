//
//  RootView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/7/26.
//

import SwiftUI

struct RootView: View {
    @Environment(Router.self) private var router
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var photoSync = PhotoSyncCoordinator()
    @State private var pictureViewModel = PictureViewModel()

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            Group {
                if hasCompletedOnboarding {
                    RootTabView(pictureViewModel: pictureViewModel)
                } else {
                    SplashView()
                }
            }
            .task {
                guard hasCompletedOnboarding else { return }
                photoSync.startIfNeeded()
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
                    DeviceSelectionView()
                case .filter:
                    FilterView()
                case let .filterResult(filters):
                    FilteredPictureView(appliedFilters: filters)
                case let .photoInfoEdit(metadata):
                    PhotoInfoEditView(metadata: metadata)
                case let .photoDetail(photo):
                    PhotoDetailView(photo: photo) { action in
                        guard action == .deletePermanently else { return false }
                        return await pictureViewModel.deletePhotos(localIdentifiers: [photo.localIdentifier])
                    }
                case .myPage:
                    MyPageView()
                case .registeredDeviceManagement:
                    RegisteredDeviceManagementView()
                }
            }
        }
        .environment(photoSync)
    }
}
