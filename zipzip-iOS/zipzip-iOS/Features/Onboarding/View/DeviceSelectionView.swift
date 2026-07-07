//
//  DeviceSelectionView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/7/26.
//

import SwiftUI

struct DeviceSelectionView: View {
    var body: some View {
        VStack(spacing: 60) {
            Text("내가 주로 사용하는 기기를\n선택해 주세요.")
                .font(.h1_sb)
                .foregroundStyle(Color(.grey900))
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(.grey100)
                .frame(maxWidth: .infinity, maxHeight: 420)

            Spacer()

            VStack(spacing: 18) {
                UnderlinedTextButton(
                    title: "목록에 내 기기가 없어요",
                    style: .medium
                ) {}

                CommonButton(title: "확인", property1: .default) {}
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 15)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.orange30)
    }
}

#Preview {
    DeviceSelectionView()
}
