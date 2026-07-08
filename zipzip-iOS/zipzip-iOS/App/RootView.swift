//
//  RootView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/7/26.
//

import SwiftUI

struct RootView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            RootTabView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .filter:
                        FilterView()
                    case let .filterResult(filters):
                        FilteredPictureView(appliedFilters: filters)
                    case let .photoInfoEdit(metadata):
                        PhotoInfoEditView(metadata: metadata)
                    case let .photoDetail(photo):
                        PhotoDetailView(photo: photo)
                    }
                }
        }
    }
}
