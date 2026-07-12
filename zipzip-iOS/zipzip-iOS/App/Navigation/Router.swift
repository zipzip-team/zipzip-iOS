//
//  Router.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import SwiftUI

@Observable
final class Router {
    var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = []
    }
}
