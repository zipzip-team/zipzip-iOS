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

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            Group {
                if hasCompletedOnboarding {
                    RootTabView()
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
                    DeviceSelectionView(store: container.registeredDeviceStore)
                case .filter:
                    FilterView()
                case let .filterResult(filters):
                    FilteredPictureView(appliedFilters: filters)
                case let .photoInfoEdit(metadata):
                    PhotoInfoEditView(metadata: metadata)
                case let .photoDetail(photo):
                    PhotoDetailView(photo: photo)
                case .myPage:
                    MyPageView()
                case .registeredDeviceManagement:
                    RegisteredDeviceManagementView(store: container.registeredDeviceStore)
                }
            }
        }
        .environment(photoSync)
    }
}
