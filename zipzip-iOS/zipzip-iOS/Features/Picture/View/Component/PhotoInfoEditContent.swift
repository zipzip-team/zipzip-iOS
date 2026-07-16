//
//  PhotoInfoEditContent.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct PhotoInfoEditContent: View {
    @State private var metadata: PhotoMetadata
    @State private var showDeviceSheet = false
    @State private var pickerDevice = ""
    @State private var deviceBeforeEditing = ""
    @State private var showLocationSheet = false
    @State private var pickerLocation = ""
    @State private var locationBeforeEditing = ""
    @State private var showDateSheet = false
    @State private var pickerDate = Date()
    @State private var dateBeforeEditing = Date()
    @State private var viewModel: PhotoInfoEditViewModel

    private let showsHeader: Bool

    init(
        metadata: PhotoMetadata,
        localIdentifiers: [String] = [],
        showsHeader: Bool = true,
        onLocalIdentifiersChange: @escaping ([String]) -> Void = { _ in },
        viewModel: PhotoInfoEditViewModel? = nil
    ) {
        _metadata = State(initialValue: metadata)
        _viewModel = State(initialValue: viewModel ?? PhotoInfoEditViewModel(
            localIdentifiers: localIdentifiers,
            onIdentifiersChanged: onLocalIdentifiersChange
        ))
        self.showsHeader = showsHeader
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsHeader {
                header
            }

            VStack(alignment: .leading, spacing: 16) {
                metadataSection(title: "기기", showsTopDivider: showsHeader, onEdit: editDevice) {
                    deviceChip
                }

                metadataSection(title: "장소", showsTopDivider: true, onEdit: editLocation) {
                    locationChip
                }

                metadataSection(title: "날짜", showsTopDivider: true, onEdit: editDate) {
                    dateChip
                }
            }
            .padding(.top, showsHeader ? 40 : 0)
        }
        .bottomSheet(isPresented: $showDeviceSheet, detents: [.content]) { dismiss in
            DeviceFilterSheet(devices: viewModel.devices, selected: $pickerDevice, onCancel: dismiss) {
                applyDevice(pickerDevice)
                dismiss()
            }
        }
        .bottomSheet(isPresented: $showLocationSheet, detents: [.full]) { dismiss in
            LocationSearchSheet(
                selected: $pickerLocation,
                onCancel: { dismiss() },
                onDone: { name, latitude, longitude in
                    applyLocation(name, latitude: latitude, longitude: longitude)
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
            await viewModel.load()
        }
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
        showsTopDivider: Bool,
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
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
            }
            chip()
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            if showsTopDivider {
                Rectangle()
                    .fill(.grey70)
                    .frame(height: 1)
            }
        }
    }

    @ViewBuilder private var deviceChip: some View {
        if isDeviceMissing {
            emptyInfoLabel("기기 정보 없음", action: editDevice)
        } else {
            DeviceMetadataChip(
                name: metadata.deviceName,
                type: metadata.deviceType,
                isSelected: false,
                action: editDevice
            )
        }
    }

    @ViewBuilder private var locationChip: some View {
        if metadata.location.isEmpty {
            emptyInfoLabel("장소 정보 없음", action: editLocation)
        } else {
            TextMetadataChip(title: metadata.location, isSelected: false, action: editLocation)
        }
    }

    @ViewBuilder private var dateChip: some View {
        if metadata.dateText.isEmpty {
            emptyInfoLabel("시간 정보 없음", action: editDate)
        } else {
            Button(action: editDate) {
                DateMetadataChip(dateText: metadata.dateText)
            }
            .buttonStyle(.plain)
        }
    }

    private var isDeviceMissing: Bool {
        metadata.deviceName.isEmpty || metadata.deviceName == DeviceCategory.unknown.typeLabel
    }

    private func emptyInfoLabel(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.b2_md)
                .foregroundStyle(.grey400)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.grey70, in: .rect(cornerRadius: 8))
                .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func editDevice() {
        pickerDevice = metadata.deviceName
        deviceBeforeEditing = pickerDevice
        showDeviceSheet = true
    }

    private func editLocation() {
        pickerLocation = metadata.location
        locationBeforeEditing = pickerLocation
        showLocationSheet = true
    }

    private func editDate() {
        pickerDate = AppliedFilter.date(from: metadata.dateText) ?? Date()
        dateBeforeEditing = pickerDate
        showDateSheet = true
    }

    private func applyDevice(_ name: String) {
        guard name != deviceBeforeEditing else { return }
        guard let device = viewModel.devices.first(where: { $0.name == name }) else { return }
        metadata = PhotoMetadata(
            deviceName: device.name,
            deviceType: device.type,
            location: metadata.location,
            dateText: metadata.dateText
        )
        viewModel.saveDevice(name: name)
    }

    private func applyLocation(_ name: String, latitude: Double?, longitude: Double?) {
        guard name != locationBeforeEditing else { return }
        metadata = PhotoMetadata(
            deviceName: metadata.deviceName,
            deviceType: metadata.deviceType,
            location: name,
            dateText: metadata.dateText
        )
        viewModel.saveLocation(name: name, latitude: latitude, longitude: longitude)
    }

    private func applyDate(_ date: Date) {
        guard date != dateBeforeEditing else { return }
        metadata = PhotoMetadata(
            deviceName: metadata.deviceName,
            deviceType: metadata.deviceType,
            location: metadata.location,
            dateText: AppliedFilter.dateText(date)
        )
        viewModel.saveDate(date)
    }
}

#Preview {
    PhotoInfoEditContent(
        metadata: PhotoMetadata.samples[0],
        viewModel: PhotoInfoEditViewModel(devices: PhotoFilterOptions.sample.devices)
    )
    .padding(.horizontal, 16)
    .background(Color.orange30)
}
