//
//  PhotoPermissionViewModel.swift
//  zipzip-iOS
//
//  Created by Codex on 7/8/26.
//

import Photos
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class PhotoPermissionViewModel {
    var didAuthorizePhotoAccess = false
    var showsPermissionAlert = false

    func requestPhotoPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized:
            didAuthorizePhotoAccess = true
        case .limited:
            presentLimitedPhotoPicker()
        case .notDetermined:
            requestAuthorization()
        case .denied, .restricted:
            showsPermissionAlert = true
        @unknown default:
            showsPermissionAlert = true
        }
    }

    func handlePhotoAccessGranted(using coordinator: PhotoSyncCoordinator) {
        coordinator.startIfNeeded()
    }

    func dismissPermissionAlert() {
        showsPermissionAlert = false
    }

    func openAppSettings() {
        showsPermissionAlert = false

        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }

        UIApplication.shared.open(settingsURL)
    }

    /// 설정 앱에서 권한을 변경하고 돌아왔을 때(포그라운드 복귀) 현재 권한을 다시 확인한다.
    func refreshAuthorizationStatusOnForeground() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            showsPermissionAlert = false
            didAuthorizePhotoAccess = true
        default:
            break
        }
    }

    private func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            Task { @MainActor [weak self, status] in
                self?.handleAuthorizationStatus(status)
            }
        }
    }

    private func handleAuthorizationStatus(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized:
            didAuthorizePhotoAccess = true
        case .limited:
            didAuthorizePhotoAccess = true
        case .denied, .restricted:
            showsPermissionAlert = true
        case .notDetermined:
            break
        @unknown default:
            showsPermissionAlert = true
        }
    }

    private func presentLimitedPhotoPicker() {
        guard let viewController = UIApplication.shared.topMostViewController else {
            didAuthorizePhotoAccess = true
            return
        }

        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)

        Task { @MainActor [weak self, weak viewController] in
            await self?.waitForLimitedPhotoPickerDismissal(from: viewController)
        }
    }

    private func waitForLimitedPhotoPickerDismissal(from viewController: UIViewController?) async {
        while viewController?.presentedViewController != nil {
            try? await Task.sleep(for: .milliseconds(200))
        }

        didAuthorizePhotoAccess = true
    }
}

extension UIApplication {
    fileprivate var topMostViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topMostPresentedViewController
    }
}

extension UIViewController {
    fileprivate var topMostPresentedViewController: UIViewController {
        presentedViewController?.topMostPresentedViewController ?? self
    }
}
