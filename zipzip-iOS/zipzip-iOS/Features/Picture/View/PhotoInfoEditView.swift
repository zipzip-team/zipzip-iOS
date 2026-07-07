//
//  PhotoInfoEditView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct PhotoInfoEditView: View {
    @Environment(Router.self) private var router

    let metadata: PhotoMetadata

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header

                metadataSection(title: "기기") {
                    DeviceMetadataChip(
                        name: metadata.deviceName,
                        type: metadata.deviceType,
                        isSelected: false
                    ) {}
                }

                metadataSection(title: "장소") {
                    LocationMetadataChip(title: metadata.location, isSelected: false) {}
                }

                metadataSection(title: "날짜") {
                    DateMetadataChip(dateText: metadata.dateText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.orange30.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .topLeading) {
            backButton
        }
    }

    private var backButton: some View {
        RoundedIconButton(items: [
            .init(id: "back", icon: .iconChevronLeft) { router.pop() }
        ])
        .opacity(0.9)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("사진 정보")
                .font(.t1_sb)
                .foregroundStyle(.grey1000)
            Text("선택한 사진 중 첫 번째 사진의 원본 정보가 아래에 표시됩니다.\n올바른 정보로 조정하면 모든 사진의 정보가 조정됩니다.")
                .font(.b2_md)
                .foregroundStyle(.grey700)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(0.9)
    }

    private func metadataSection<Chip: View>(
        title: String,
        @ViewBuilder chip: () -> Chip
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(title)
                    .font(.t3_sb)
                    .foregroundStyle(.grey1000)
                Spacer()
                Button { /* TODO: 수정 */ } label: {
                    Text("수정")
                        .font(.b3_sb)
                        .foregroundStyle(.grey500)
                        .underline()
                }
                .buttonStyle(.plain)
            }
            chip()
        }
    }
}

#Preview {
    PhotoInfoEditView(metadata: PhotoMetadata.samples[0])
        .environment(Router())
}
