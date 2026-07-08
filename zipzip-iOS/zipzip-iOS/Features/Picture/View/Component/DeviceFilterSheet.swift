//
//  DeviceFilterSheet.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct DeviceFilterSheet: View {
    let devices: [FilterDevice]
    @Binding var selected: String
    let onDone: () -> Void

    var body: some View {
        BottomSheet(rightItem: {
            Button(action: onDone) {
                Text("완료")
                    .font(.b1_sb)
                    .foregroundStyle(.white00)
                    .frame(width: 72, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }) {
            VStack(alignment: .leading, spacing: 20) {
                titleBlock

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(devices, id: \.name) { device in
                            DeviceMetadataChip(
                                name: device.name,
                                type: device.type,
                                isSelected: selected == device.name
                            ) {
                                selected = device.name
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("기기")
                .font(.t3_sb)
                .foregroundStyle(.white00)
            Text("불러온 기기 중 많이 쓴 기기를 기준으로 추천해요.")
                .font(.b2_md)
                .foregroundStyle(.grey300)
        }
    }
}

#Preview {
    DeviceFilterSheet(
        devices: PhotoFilterOptions.sample.devices,
        selected: .constant("Sony Alpha a7 III"),
        onDone: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(.black)
}
