//
//  MainView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/5/26.
//

import SQLiteData
import SwiftUI

struct MainView: View {
    @Environment(Router.self) private var router
    @Environment(PhotoSyncCoordinator.self) private var photoSync

    @Fetch(RegisteredPhotoCountRequest()) private var registeredPhotoCount = 0

    @State private var showCancelAlert = false

    private let organizedPhotoCount: Int

    private enum Layout {
        static let heroHeight: CGFloat = 420
        static let sectionSpacing: CGFloat = 28
        static let horizontalPadding: CGFloat = 16
        static let organizedPhotoCountTopPadding: CGFloat = 134
    }

    init(organizedPhotoCount: Int = 0) {
        self.organizedPhotoCount = organizedPhotoCount
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white00
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Layout.sectionSpacing) {
                    heroSection
                    unresolvedPhotosSection
                }
            }
            .ignoresSafeArea(edges: .top)

            floatingHeader
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            FloatingHeader(.trailing) {
                ProfileButton {
                    guard router.path.isEmpty else { return }
                    router.push(.myPage)
                }
            }
        }
        .bottomSheetAlert(
            isPresented: $showCancelAlert,
            title: cancelAlertTitle,
            message: "업로드 중에 앱을 종료하면 다시 처음부터 해야해요.",
            secondaryTitle: cancelAlertSecondaryTitle,
            primaryTitle: "확인",
            onSecondaryTap: { photoSync.cancelSync() },
            onPrimaryTap: {}
        )
    }

    private var indicatorMode: MoveInIndicator.Mode {
        photoSync.phase == .uploading ? .uploading : .moveIn
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

    private var heroSection: some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle()
                .fill(.orange30)
                .frame(height: Layout.heroHeight)

            Image(.zip01)

            organizedPhotoCountView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, Layout.organizedPhotoCountTopPadding)
                .padding(.horizontal, Layout.horizontalPadding)
        }
    }

    private var organizedPhotoCountView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("집집에서 정리한 사진")
                .font(.t3_md)

            HStack(alignment: .bottom, spacing: 2) {
                Text(organizedPhotoCount, format: .number)
                    .font(.h1_sb)

                Text("장")
                    .font(.b1_md)
                    .padding(.bottom, 6)
            }
        }
        .foregroundStyle(.grey1000)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("집집에 모인 사진 \(organizedPhotoCount.formatted(.number))장")
    }

    private var unresolvedPhotosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("아직 머물 곳을 찾는 사진들")
                    .font(.t2_sb)
                    .foregroundStyle(.grey1000)

                Text("지금 정리하면 좋을 사진을 모았어요")
                    .font(.b2_md)
                    .foregroundStyle(.grey500)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    HomePhotoCard(
                        eyebrow: "어딜 다녀왔더라?",
                        title: "장소를 모르는 사진",
                        backgroundColor: .orange200,
                        buttonBackgroundColor: .orange100,
                        image: .homeCard01,
                        action: {
                            router.push(.filterResult([
                                AppliedFilter(
                                    kind: .etc,
                                    value: PhotoFilterOptions.EtcItem.noLocation
                                )
                            ]))
                        }
                    )

                    HomePhotoCard(
                        eyebrow: "어떤 사진을 찍었지?",
                        title: "최근 저장된 사진",
                        backgroundColor: .skyblue500,
                        buttonBackgroundColor: .skyblue100,
                        image: .homeCard02,
                        action: {
                            router.push(.filterResult([
                                AppliedFilter(
                                    kind: .etc,
                                    value: PhotoFilterOptions.EtcItem.recentlyAdded
                                )
                            ]))
                        }
                    )

                    HomePhotoCard(
                        eyebrow: "어떤 걸로 찍었지?",
                        title: "등록된 기기 확인",
                        backgroundColor: .yellow400,
                        buttonBackgroundColor: .white00,
                        image: .homeCard03,
                        action: {
                            router.push(.registeredDeviceManagement)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }

    private var floatingHeader: some View {
        FloatingHeaderBar {
            ZStack {
                HStack(spacing: 0) {
                    Image(.badgeLogo)
                        .frame(width: 44, height: 44)

                    Spacer()
                }

                if photoSync.isProcessing {
                    MoveInIndicator(
                        mode: indicatorMode,
                        remainingMinutes: photoSync.remainingMinutes,
                        tooltipText: registeredPhotoCount > 0
                            ? "\(registeredPhotoCount)장의 사진이 입주했어요!"
                            : nil,
                        onTap: { showCancelAlert = true }
                    )
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: photoSync.isProcessing)
    }
}

#Preview {
    MainView(organizedPhotoCount: 7018)
        .environment(Router())
        .environment(PhotoSyncCoordinator())
}
