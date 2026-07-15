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
    let authenticationState: AuthenticationState
    let networkProvider: NetworkProvider
    let shareGroupRepository: ShareGroupRepository
    let sharedPhotoRepository: SharedPhotoRepository
    let registeredDeviceStore: RegisteredDeviceStore

    init(
        networkProvider: NetworkProvider? = nil,
        registeredDeviceStore: RegisteredDeviceStore? = nil
    ) {
        let publicNetworkProvider = networkProvider ?? DefaultNetworkProvider()
        let authAPI = DefaultAuthAPI(networkProvider: publicNetworkProvider)
        let credentialStore = KeychainCredentialStore()
        let credentialController = SessionCredentialController(
            store: credentialStore,
            authAPI: authAPI
        )

        let authenticationState = AuthenticationState(
            authAPI: authAPI,
            credentialController: credentialController
        )
        self.authenticationState = authenticationState
        let authenticatedNetworkProvider = AuthenticatedNetworkProvider(
            provider: publicNetworkProvider,
            credentialController: credentialController,
            onAuthenticationLost: { [weak authenticationState] in
                authenticationState?.handleAuthenticationLost()
            }
        )
        self.networkProvider = authenticatedNetworkProvider
        self.shareGroupRepository = DefaultShareGroupRepository(
            api: DefaultShareGroupAPI(networkProvider: authenticatedNetworkProvider)
        )
        self.sharedPhotoRepository = DefaultSharedPhotoRepository(
            api: DefaultSharedPhotoAPI(networkProvider: authenticatedNetworkProvider)
        )
        self.registeredDeviceStore = registeredDeviceStore ?? DefaultRegisteredDeviceStore()
    }
}
