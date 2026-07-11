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
    let registeredDeviceStore: RegisteredDeviceStore

    init(
        networkProvider: NetworkProvider? = nil,
        registeredDeviceStore: RegisteredDeviceStore? = nil
    ) {
        self.networkProvider = networkProvider ?? DefaultNetworkProvider()
        self.registeredDeviceStore = registeredDeviceStore ?? DefaultRegisteredDeviceStore()
    }
}
