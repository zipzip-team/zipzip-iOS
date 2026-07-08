//
//  MainView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/5/26.
//

import SwiftUI

struct MainView: View {
    private enum Layout {
        static let heroHeight: CGFloat = 402
        static let sectionSpacing: CGFloat = 32
        static let horizontalPadding: CGFloat = 16
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.orange30
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
    }

    private var heroSection: some View {
        Rectangle()
            .fill(.grey70)
            .frame(height: Layout.heroHeight)
    }

    private var unresolvedPhotosSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("아직 머물 곳을 찾는 사진들")
                    .font(.t2_sb)
                    .foregroundStyle(.grey1000)

                Text("아직 머물 곳을 찾는 사진들")
                    .font(.b2_md)
                    .foregroundStyle(.grey500)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    HomePhotoCard(
                        eyebrow: "어딜 다녀왔더라?",
                        title: "장소를 모르는 사진",
                        backgroundColor: .orange400,
                        imageWidth: 112
                    )

                    HomePhotoCard(
                        eyebrow: "어떤 사진을 찍었지?",
                        title: "최근 저장된 사진",
                        backgroundColor: Color(red: 0.74, green: 0.87, blue: 0.94),
                        imageWidth: 112
                    )

                    HomePhotoCard(
                        eyebrow: "어떤 걸로 찍었지?",
                        title: "등록된 기기 확인",
                        backgroundColor: .yellow500,
                        imageWidth: 112
                    )
                }
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }

    private var floatingHeader: some View {
        HStack {
            Button {} label: {
                Text("logo")
                    .font(.b2_md)
                    .foregroundStyle(.grey1000)
                    .frame(width: 44, height: 44)
                    .background(.grey200, in: RoundedRectangle(cornerRadius: 6.67, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer()

            ProfileButton {}
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }
}

#Preview {
    MainView()
}
