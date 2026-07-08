//
//  DeviceSelectionView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/7/26.
//

import SwiftUI

struct DeviceSelectionView: View {
    @Environment(Router.self) private var router
    @State private var devices = DetectedDevice.samples
    @State private var selectedDeviceIDs = Set<DetectedDevice.ID>()

    var body: some View {
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

                VStack(spacing: 16) {
                    ForEach(devices) { device in
                        DeviceSelectionButton(
                            title: device.name,
                            subtitle: device.modelName,
                            icon: device.type.icon,
                            iconSize: device.type.iconSize,
                            isSelected: selectedDeviceIDs.contains(device.id)
                        ) {
                            toggleSelection(for: device)
                        }
                    }
                }

                Spacer()

                CommonButton(title: "확인", property1: .default) {
                    router.push(.serviceIntro)
                }
            }
        }
    }

    private func toggleSelection(for device: DetectedDevice) {
        if selectedDeviceIDs.contains(device.id) {
            selectedDeviceIDs.remove(device.id)
        } else {
            selectedDeviceIDs.insert(device.id)
        }
    }
}

#Preview {
    DeviceSelectionView()
        .environment(Router())
}
