//
//  MoveInIndicatorBar.swift
//  zipzip-iOS
//

import SQLiteData
import SwiftUI

struct MoveInIndicatorBar: View {
    @Environment(PhotoSyncCoordinator.self) private var photoSync

    @Fetch(RegisteredPhotoCountRequest()) private var registeredPhotoCount = 0

    @State private var showCancelAlert = false

    var body: some View {
        FloatingHeaderBar {
            if photoSync.isProcessing {
                MoveInIndicator(
                    mode: indicatorMode,
                    remainingMinutes: photoSync.remainingMinutes,
                    tooltipText: indicatorMode == .moveIn && registeredPhotoCount > 0
                        ? "\(registeredPhotoCount)장의 사진이 입주했어요!"
                        : nil,
                    onTap: { showCancelAlert = true }
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: photoSync.isProcessing)
        .bottomSheetAlert(
            isPresented: $showCancelAlert,
            title: cancelAlertTitle,
            message: "업로드 중에 앱을 종료하면 다시 처음부터 해야해요.",
            secondaryTitle: cancelAlertSecondaryTitle,
            primaryTitle: "확인",
            onSecondaryTap: {
                showCancelAlert = false
                photoSync.cancelSync()
            },
            onPrimaryTap: { showCancelAlert = false }
        )
    }

    private var indicatorMode: MoveInIndicator.Mode {
        photoSync.isUploading || photoSync.phase == .uploading ? .uploading : .moveIn
    }

    private var cancelAlertTitle: String {
        let durationText = photoSync.remainingMinutes.map(MoveInIndicator.durationText)
        switch indicatorMode {
        case .moveIn:
            return durationText.map { "사진 동기화까지 \($0) 남았어요" } ?? "사진 동기화를 중단할까요?"
        case .uploading:
            return durationText.map { "사진 업로드까지 \($0) 남았어요" } ?? "사진 업로드를 중단할까요?"
        }
    }

    private var cancelAlertSecondaryTitle: String {
        indicatorMode == .uploading ? "업로드 취소" : "불러오기 취소"
    }
}
