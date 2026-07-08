//
//  FilterView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/7/26.
//

import SwiftUI
import UIKit

struct FilterView: View {
    @Environment(Router.self) private var router
    @State private var viewModel = FilterViewModel()
    @State private var showDateSheet = false
    @State private var pickerDate = Date()

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
        .bottomSheet(isPresented: $showDateSheet, detents: [.height(dateSheetHeight)]) { dismiss in
            DateFilterSheet(date: $pickerDate) {
                viewModel.selectDate(pickerDate)
                dismiss()
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                CommonButton(title: "초기화", property1: .secondary) { viewModel.reset() }
                CommonButton(title: "다음", property1: .cta) {
                    router.push(.filterResult(viewModel.appliedFilters))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var dateSheetHeight: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        let screenHeight = window?.bounds.height ?? 0
        let topInset = window?.safeAreaInsets.top ?? 0
        let backButtonArea: CGFloat = 50
        let gap: CGFloat = 46
        return max(screenHeight - topInset - backButtonArea - gap, 1)
    }

    private var deviceSection: some View {
        section(title: "기기", subtitle: "불러온 기기 중 많이 쓴 기기를 기준으로 추천해요.") {
            chipRow {
                ForEach(viewModel.options.devices, id: \.name) { device in
                    DeviceMetadataChip(
                        name: device.name,
                        type: device.type,
                        isSelected: viewModel.selectedDevice == device.name
                    ) {
                        viewModel.selectDevice(device.name)
                    }
                }
            }
        }
    }

    private var locationSection: some View {
        section(title: "장소", subtitle: "사진을 많이 찍은 장소를 기준으로 추천해요.") {
            chipRow {
                ForEach(viewModel.options.locations, id: \.self) { location in
                    LocationMetadataChip(
                        title: location,
                        isSelected: viewModel.selectedLocation == location
                    ) {
                        viewModel.selectLocation(location)
                    }
                }
            }
        }
    }

    private var dateSection: some View {
        section(title: "날짜", subtitle: "사진을 찍은 날짜를 선택해 주세요.") {
            Button {
                pickerDate = viewModel.selectedDate ?? Date()
                showDateSheet = true
            } label: {
                DateMetadataChip(dateText: viewModel.displayDateText)
            }
            .buttonStyle(.plain)
        }
    }

    private var etcSection: some View {
        section(title: "기타", subtitle: nil) {
            chipRow {
                ForEach(viewModel.options.etcItems, id: \.self) { item in
                    LocationMetadataChip(
                        title: item,
                        isSelected: viewModel.selectedEtc == item
                    ) {
                        viewModel.selectEtc(item)
                    }
                }
            }
        }
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
}

#Preview {
    FilterView()
        .environment(Router())
}
