//
//  Alty_iOSApp.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import SwiftUI

@main
struct zipzip_iOSApp: App {
    @State private var router = Router()
    @State private var container = DIContainer()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(router)
                .environment(container)
        }
    }
}
