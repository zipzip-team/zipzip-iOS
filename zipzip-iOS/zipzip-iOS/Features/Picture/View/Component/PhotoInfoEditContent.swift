//
//  PhotoInfoEditContent.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SQLiteData
import SwiftUI

struct PhotoInfoEditContent: View {
    @Dependency(\.photoFilterOptions) private var filterOptions

    @State private var metadata: PhotoMetadata
    @State private var showDeviceSheet = false
    @State private var pickerDevice = ""
    @State private var showLocationSheet = false
    @State private var pickerLocation = ""
    @State private var showDateSheet = false
    @State private var pickerDate = Date()
    @State private var devices: [FilterDevice] = []

    init(metadata: PhotoMetadata) {
        _metadata = State(initialValue: metadata)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 0) {
                metadataSection(title: "기기", hasDivider: true, onEdit: {
                    pickerDevice = metadata.deviceName
                    showDeviceSheet = true
                }) {
                    DeviceMetadataChip(
                        name: metadata.deviceName,
                        type: metadata.deviceType,
                        isSelected: false
                    ) {}
                }

                metadataSection(title: "장소", hasDivider: true, onEdit: {
                    pickerLocation = metadata.location
                    showLocationSheet = true
                }) {
                    TextMetadataChip(title: metadata.location, isSelected: false) {}
                }

                metadataSection(title: "날짜", hasDivider: false, onEdit: {
                    pickerDate = AppliedFilter.date(from: metadata.dateText) ?? Date()
                    showDateSheet = true
                }) {
                    DateMetadataChip(dateText: metadata.dateText)
                }
            }
            .padding(.top, 40)
        }
        .bottomSheet(isPresented: $showDeviceSheet, detents: [.content]) { dismiss in
            DeviceFilterSheet(devices: devices, selected: $pickerDevice) {
                applyDevice(pickerDevice)
                dismiss()
            }
        }
        .bottomSheet(isPresented: $showLocationSheet, detents: [.full]) { dismiss in
            LocationSearchSheet(
                selected: $pickerLocation,
                onCancel: { dismiss() },
                onDone: {
                    applyLocation(pickerLocation)
                    dismiss()
                }
            )
        }
        .bottomSheet(isPresented: $showDateSheet, detents: [.full]) { dismiss in
            DateTimeEditSheet(
                date: $pickerDate,
                onCancel: { dismiss() },
                onDone: {
                    applyDate(pickerDate)
                    dismiss()
                }
            )
        }
        .task {
            await loadDevices()
        }
    }

    private func loadDevices() async {
        devices = (try? await filterOptions.load())?.devices ?? []
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("사진 정보")
                .font(.t1_sb)
                .foregroundStyle(.grey1000)
            Text("선택한 사진 중 첫 번째 사진의 정보를 기준으로 보여드려요.\n정보를 수정하면 모든 사진에 함께 적용돼요.")
                .font(.b2_md)
                .foregroundStyle(.grey700)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(0.9)
    }

    private func metadataSection<Chip: View>(
        title: String,
        hasDivider: Bool,
        onEdit: @escaping () -> Void,
        @ViewBuilder chip: () -> Chip
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(title)
                    .font(.t3_sb)
                    .foregroundStyle(.grey1000)
                Spacer()
                Button(action: onEdit) {
                    Text("수정")
                        .font(.b3_sb)
                        .foregroundStyle(.grey500)
                        .underline()
                }
                .buttonStyle(.plain)
            }
            chip()
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            if hasDivider {
                Rectangle()
                    .fill(.grey70)
                    .frame(height: 1)
            }
        }
    }

    private func applyDevice(_ name: String) {
        guard let device = devices.first(where: { $0.name == name }) else { return }
        metadata = PhotoMetadata(
            deviceName: device.name,
            deviceType: device.type,
            location: metadata.location,
            dateText: metadata.dateText
        )
    }

    private func applyLocation(_ name: String) {
        metadata = PhotoMetadata(
            deviceName: metadata.deviceName,
            deviceType: metadata.deviceType,
            location: name,
            dateText: metadata.dateText
        )
    }

    private func applyDate(_ date: Date) {
        metadata = PhotoMetadata(
            deviceName: metadata.deviceName,
            deviceType: metadata.deviceType,
            location: metadata.location,
            dateText: AppliedFilter.dateText(date)
        )
    }
}

#Preview {
    PhotoInfoEditContent(metadata: PhotoMetadata.samples[0])
        .padding(.horizontal, 16)
        .background(Color.orange30)
}
