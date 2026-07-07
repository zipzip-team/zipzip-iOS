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

            Rectangle()
                .fill(.grey100)
                .frame(maxWidth: .infinity, maxHeight: 420)

            Spacer()

            CommonButton(title: "확인", property1: .default) {}
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
