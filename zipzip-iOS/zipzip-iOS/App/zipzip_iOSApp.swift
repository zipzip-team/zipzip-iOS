//
//  Alty_iOSApp.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import SQLiteData
import SwiftUI

@main
struct zipzip_iOSApp: App {
    @State private var router = Router()
    @State private var container: DIContainer

    init() {
        prepareAppDependencies()
        _container = State(initialValue: DIContainer())
    }

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                RootView(shareGroupRepository: container.shareGroupRepository)
                    .environment(router)
                    .environment(container)
                    .environment(container.authenticationState)
            } else {
                Color.clear
            }
        }
    }
}
