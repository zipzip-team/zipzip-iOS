//
//  ServiceIntroView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/8/26.
//

import SwiftUI

struct ServiceIntroView: View {
    var body: some View {
        VStack(spacing: 60) {
            VStack(spacing: 8) {
                Image(.serviceIntroText1)
                
                Text("여러 기기에 흩어진 사진들을 모아\n나만의 사진집으로 정리해요.")
                    .font(.b1_md)
                    .foregroundStyle(Color(.grey400))
                    .frame(alignment: .init(horizontal: .leading, vertical: .top))
            }
            
            Rectangle()
                .fill(.grey100)
                .frame(maxWidth: .infinity, maxHeight: 420)
            
            Spacer()
            
            CommonButton(title: "확인", property1: .default) {}
        }
        .padding(.top, 38)
        .padding(.bottom, 15)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.orange30)
    }
}

#Preview {
    ServiceIntroView()
}
