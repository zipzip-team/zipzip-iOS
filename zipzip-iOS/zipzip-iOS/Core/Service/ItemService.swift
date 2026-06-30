//
//  ItemService.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Foundation

protocol ItemService {
    func addItem()
    func deleteItems(_ items: [Item])
}

final class DefaultItemService: ItemService {
    private let repository: ItemRepository

    init(repository: ItemRepository) {
        self.repository = repository
    }

    func addItem() {
        repository.add(Item(timestamp: Date()))
    }

    func deleteItems(_ items: [Item]) {
        for item in items {
            repository.delete(item)
        }
    }
}
