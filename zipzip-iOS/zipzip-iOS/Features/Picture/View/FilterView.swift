//
//  FilterView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/7/26.
//

import SwiftUI

struct FilterView: View {
    @Environment(Router.self) private var router

    @State private var selectedDevice: String?
    @State private var selectedLocation: String?
    @State private var selectedEtc: String?

    private let options: PhotoFilterOptions = .sample

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RoundedIconButton(items: [
                    .init(id: "back", icon: .iconChevronLeft) { router.pop() }
                ])
                .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 32) {
                    deviceSection
                    locationSection
                    dateSection
                    etcSection
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.orange30.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                CommonButton(title: "초기화", property1: .secondary) { reset() }
                CommonButton(title: "다음", property1: .cta) {
                    let labels = [selectedDevice, selectedLocation, selectedEtc].compactMap { $0 }
                    router.push(.filterResult(labels))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var deviceSection: some View {
        section(title: "기기", subtitle: "불러온 기기 중 많이 쓴 기기를 기준으로 추천해요.") {
            chipRow {
                ForEach(options.devices, id: \.name) { device in
                    DeviceMetadataChip(
                        name: device.name,
                        type: device.type,
                        isSelected: selectedDevice == device.name
                    ) {
                        selectedDevice = device.name
                    }
                }
            }
        }
    }

    private var locationSection: some View {
        section(title: "장소", subtitle: "사진을 많이 찍은 장소를 기준으로 추천해요.") {
            chipRow {
                ForEach(options.locations, id: \.self) { location in
                    LocationMetadataChip(
                        title: location,
                        isSelected: selectedLocation == location
                    ) {
                        selectedLocation = location
                    }
                }
            }
        }
    }

    private var dateSection: some View {
        section(title: "날짜", subtitle: "사진을 찍은 날짜를 선택해 주세요.") {
            dateChip
        }
    }

    private var etcSection: some View {
        section(title: "기타", subtitle: nil) {
            chipRow {
                ForEach(options.etcItems, id: \.self) { item in
                    LocationMetadataChip(
                        title: item,
                        isSelected: selectedEtc == item
                    ) {
                        selectedEtc = item
                    }
                }
            }
        }
    }

    private var dateChip: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(.white00)
                    .frame(width: 20, height: 20)
                Image(.calendar)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.grey950)
            }
            Text(options.dateText)
                .font(.b2_md)
                .foregroundStyle(.grey950)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.grey70, in: .rect(cornerRadius: 8))
    }

    private func section<Content: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.t3_sb)
                    .foregroundStyle(.grey1000)
                if let subtitle {
                    Text(subtitle)
                        .font(.b2_md)
                        .foregroundStyle(.grey700)
                }
            }
            content()
        }
    }

    private func chipRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content()
            }
        }
    }

    private func reset() {
        selectedDevice = nil
        selectedLocation = nil
        selectedEtc = nil
    }
}

#Preview {
    FilterView()
        .environment(Router())
}
