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
        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(container)
        }
    }
}
