//
//  DIContainer.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Observation

@MainActor
@Observable
final class DIContainer {
    let networkProvider: NetworkProvider

    init(networkProvider: NetworkProvider? = nil) {
        self.networkProvider = networkProvider ?? DefaultNetworkProvider()
    }
}
