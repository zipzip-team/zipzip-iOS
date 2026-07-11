//
//  ServiceIntroPage.swift
//  zipzip-iOS
//
//  Created by Codex on 7/8/26.
//

import SwiftUI

struct ServiceIntroPage {
    let titleImage: ImageResource
    let description: String
    let illustrationImage: ImageResource?
}

extension ServiceIntroPage {
    static let pages: [ServiceIntroPage] = [
        ServiceIntroPage(
            titleImage: .serviceIntroText1,
            description: "여러 기기에 흩어진 사진들을 모아\n나만의 사진집으로 정리해요.",
            illustrationImage: .serviceIntroArtwork1
        ),
        ServiceIntroPage(
            titleImage: .serviceIntroText2,
            description: "필요한 사진을 선택하고,\n원하는 사진들을 묶어 나만의 집에 담아요.",
            illustrationImage: nil
        ),
        ServiceIntroPage(
            titleImage: .serviceIntroText3,
            description: "날짜, 장소, 기기 정보를 정리해\n사진이 제자리를 찾을 수 있도록 도와줘요.",
            illustrationImage: nil
        ),
        ServiceIntroPage(
            titleImage: .serviceIntroText4,
            description: "앨범을 만들고 초대해,\n함께 보고 함께 추억을 쌓아가요.",
            illustrationImage: nil
        )
    ]
}
