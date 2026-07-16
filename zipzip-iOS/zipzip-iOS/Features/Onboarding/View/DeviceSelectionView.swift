//
//  DeviceSelectionView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/7/26.
//

import SwiftUI

struct DeviceSelectionView: View {
    @Environment(Router.self) private var router
    @State private var viewModel: DeviceSelectionViewModel

    init(store: RegisteredDeviceStore) {
        _viewModel = State(initialValue: DeviceSelectionViewModel(store: store))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        OnboardingContainerView {
            VStack(spacing: 64) {
                VStack(spacing: 4) {
                    Text("사진을 모아보고 싶은 기기를 선택해주세요.")
                        .font(.h1_sb)
                        .foregroundStyle(Color(.grey900))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("선택한 기기로 찍은 사진들을 정리할 수 있어요.")
                        .font(.b1_md)
                        .foregroundStyle(Color(.grey400))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(viewModel.devices) { device in
                            DeviceSelectionButton(
                                title: device.modelName,
                                subtitle: device.name,
                                deviceType: device.type,
                                isSelected: viewModel.selectedDeviceIDs.contains(device.id)
                            ) {
                                viewModel.toggleSelection(for: device)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                CommonButton(
                    title: "확인",
                    property1: viewModel.isSavingSelection ? .disabled : .default
                ) {
                    Task {
                        if await viewModel.saveSelection() {
                            router.push(.onboardingComplete)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    DeviceSelectionView(store: DefaultRegisteredDeviceStore())
        .environment(Router())
}
