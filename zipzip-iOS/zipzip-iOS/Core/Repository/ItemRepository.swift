//
//  ItemRepository.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Foundation
import SwiftData

protocol ItemRepository {
    func add(_ item: Item)
    func delete(_ item: Item)
}

final class SwiftDataItemRepository: ItemRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(_ item: Item) {
        context.insert(item)
    }

    func delete(_ item: Item) {
        context.delete(item)
    }
}
