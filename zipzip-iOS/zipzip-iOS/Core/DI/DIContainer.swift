//
//  DIContainer.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import SwiftData

@MainActor
@Observable
final class DIContainer {
    let networkProvider: NetworkProvider

    init(networkProvider: NetworkProvider? = nil) {
        self.networkProvider = networkProvider ?? DefaultNetworkProvider()
    }

    func makeContentViewModel(context: ModelContext) -> ContentViewModel {
        ContentViewModel(
            service: DefaultItemService(
                repository: SwiftDataItemRepository(context: context)
            )
        )
    }
}
