//
//  RegisteredDeviceRow.swift
//  zipzip-iOS
//
//  Created by Codex on 7/9/26.
//

import SwiftUI

struct RegisteredDeviceRow: View {
    let device: DetectedDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(device.name)
                .font(.b1_md)
                .foregroundStyle(.grey1000)

            Text(device.modelName)
                .font(.b2_md)
                .foregroundStyle(.grey400)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 24)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.grey70)
                .frame(height: 1)
        }
    }
}
