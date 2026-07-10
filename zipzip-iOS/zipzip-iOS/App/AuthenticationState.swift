//
//  AuthenticationState.swift
//  zipzip-iOS
//

import Observation

@Observable
final class AuthenticationState {
    private(set) var isLoggedIn = false

    func logIn() {
        isLoggedIn = true
    }
}
