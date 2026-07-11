//
//  RegisteredDeviceManagementView.swift
//  zipzip-iOS
//
//  Created by Codex on 7/9/26.
//

import SwiftUI

struct RegisteredDeviceManagementView: View {
    @Environment(Router.self) private var router
    @State private var viewModel: RegisteredDeviceManagementViewModel

    init(store: RegisteredDeviceStore) {
        _viewModel = State(initialValue: RegisteredDeviceManagementViewModel(store: store))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        MyPageContainerView {
            floatingButtonBar
        } content: {
            VStack(alignment: .leading, spacing: 32) {
                titleSection
                deviceSection
            }
            .padding(.bottom, viewModel.showsActionBar ? 132 : 0)
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.mode == .removing {
                deleteActionBar
                    .padding(.bottom, 28)
            } else if viewModel.mode == .registering {
                registrationActionBar
                    .padding(.bottom, 28)
            }
        }
        .bottomSheetAlert(
            isPresented: $viewModel.showsDeleteAlert,
            title: "등록한 기기를 제거하시겠어요?",
            message: "제거해도 사진은 삭제되지 않아요.\n제거한 기기는 필요하면 나중에 다시 등록할 수 있어요.",
            secondaryTitle: "취소",
            primaryTitle: "제거하기",
            onSecondaryTap: {
                viewModel.dismissDeleteAlert()
            },
            onPrimaryTap: {
                Task { await viewModel.confirmDelete() }
            }
        )
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var floatingButtonBar: some View {
        if viewModel.showsActionBar {
            HStack {
                RoundedTextButton(title: "취소", style: .cancel) {
                    viewModel.cancelSelection()
                }

                Spacer(minLength: 0)
            }
        } else {
            HStack {
                RoundedIconButton(items: [
                    .init(id: "back", icon: .iconChevronLeft, accessibilityLabel: "") { router.pop() }
                ])

                Spacer(minLength: 0)

                RoundedIconButton(items: [
                    .init(id: "selection", icon: .select, accessibilityLabel: "") { viewModel.enterRemovingMode()
                    },
                    .init(id: "add", icon: .plus, accessibilityLabel: "") {
                        Task { await viewModel.enterRegisteringMode() }
                    }
                ])
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("등록 기기 관리")
                .font(.t1_sb)
                .foregroundStyle(.grey1000)

            Text("등록한 기기들의 사진을 집집에 모아서 정리할 수 있어요.")
                .font(.b2_md)
                .foregroundStyle(.grey700)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("총 \(viewModel.displayedDevices.count)대")
                .font(.b2_md)
                .foregroundStyle(.grey600)
                .padding(.horizontal, 16)

            if viewModel.showsActionBar {
                VStack(spacing: 16) {
                    ForEach(viewModel.displayedDevices) { device in
                        DeviceSelectionButton(
                            title: device.name,
                            subtitle: device.modelName,
                            deviceType: device.type,
                            isSelected: viewModel.isSelected(device)
                        ) {
                            viewModel.toggleSelection(for: device)
                        }
                    }
                }
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.registeredDevices) { device in
                        RegisteredDeviceRow(device: device)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var deleteActionBar: some View {
        ActionBar(items: [
            .init(icon: .delete, title: "제거", isDisabled: viewModel.isDeleteDisabled) {
                viewModel.requestDelete()
            }
        ])
    }

    private var registrationActionBar: some View {
        ActionBar(items: [
            .init(icon: .plus, title: "등록", isDisabled: viewModel.isRegistrationDisabled) {
                Task { await viewModel.registerSelectedDevices() }
            }
        ])
    }
}

#Preview {
    RegisteredDeviceManagementView(store: DefaultRegisteredDeviceStore())
        .environment(Router())
}
