//
//  Route.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Foundation

enum Route: Hashable {
    case splash
    case serviceIntro
    case onboardingComplete
    case photoPermission
    case deviceLoading
    case deviceSelection
    case filter
    case filterResult([AppliedFilter])
    case photoInfoEdit(PhotoMetadata)
    case photoDetail(Photo)
    case myPage
    case registeredDeviceManagement
}
