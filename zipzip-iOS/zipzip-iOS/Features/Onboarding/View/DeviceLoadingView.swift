//
//  DeviceLoadingView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/7/26.
//

import SwiftUI

struct DeviceLoadingView: View {
    var body: some View {
        VStack(spacing: 38) {
            VStack(spacing: 4) {
                Text("기기 목록을 불러오고 있어요.")
                    .font(.h1_sb)
                    .foregroundStyle(Color(.grey900))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("잠시만 기다려주세요.")
                    .font(.b1_md)
                    .foregroundStyle(Color(.grey400))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Rectangle()
                .fill(.grey100)
                .frame(maxWidth: .infinity, maxHeight: 420)

            Spacer()

            CommonButton(title: "확인", property1: .default) {}
                .frame(alignment: .bottom)
        }
        .padding(.top, 30)
        .padding(.bottom, 15)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.orange30)
    }
}

#Preview {
    DeviceLoadingView()
}
