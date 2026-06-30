//
//  ContentViewModel.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Foundation

@Observable
final class ContentViewModel {
    private let service: ItemService

    init(service: ItemService) {
        self.service = service
    }

    func addItem() {
        service.addItem()
    }

    func deleteItems(at offsets: IndexSet, items: [Item]) {
        let targets = offsets.map { items[$0] }
        service.deleteItems(targets)
    }
}
