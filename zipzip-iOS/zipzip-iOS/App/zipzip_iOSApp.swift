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
    @State private var container = DIContainer()

    init() {
        prepareAppDependencies()
    }

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                RootView()
                    .environment(router)
                    .environment(container)
                    .environment(container.authenticationState)
            } else {
                Color.clear
            }
        }
    }
}
