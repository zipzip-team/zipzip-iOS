//
//  Alty_iOSApp.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import SwiftData
import SwiftUI

@main
struct zipzip_iOSApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self

        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var router = Router()
    @State private var container = DIContainer()

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: container.makeContentViewModel(context: sharedModelContainer.mainContext)
            )
            .environment(router)
            .environment(container)
        }
        .modelContainer(sharedModelContainer)
    }
}
