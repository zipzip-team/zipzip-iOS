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
    let userProfileState: UserProfileState
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
        let shareGroupAPI = DefaultShareGroupAPI(networkProvider: authenticatedNetworkProvider)
        let sharedGroupStore = SharedGroupStore()
        self.shareGroupRepository = DefaultShareGroupRepository(
            api: shareGroupAPI,
            store: sharedGroupStore
        )
        self.sharedPhotoRepository = DefaultSharedPhotoRepository(
            api: DefaultSharedPhotoAPI(networkProvider: authenticatedNetworkProvider),
            groupAPI: shareGroupAPI,
            groupStore: sharedGroupStore
        )
        self.userProfileState = UserProfileState(
            repository: DefaultUserProfileRepository(
                api: DefaultUserProfileAPI(networkProvider: authenticatedNetworkProvider)
            )
        )
        self.registeredDeviceStore = registeredDeviceStore ?? DefaultRegisteredDeviceStore()
    }
}
