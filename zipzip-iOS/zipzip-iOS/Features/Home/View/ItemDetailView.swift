//
//  ItemDetailView.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import SwiftUI

struct ItemDetailView: View {
    let item: Item

    var body: some View {
        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
            .navigationTitle("Detail")
    }
}
