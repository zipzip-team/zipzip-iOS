//
//  ContentView.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(Router.self) private var router
    @Query private var items: [Item]
    @State private var viewModel: ContentViewModel

    init(viewModel: ContentViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            List {
                ForEach(items) { item in
                    Button {
                        router.push(.itemDetail(item))
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Items")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .itemDetail(let item):
                    ItemDetailView(item: item)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func addItem() {
        withAnimation {
            viewModel.addItem()
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            viewModel.deleteItems(at: offsets, items: items)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Item.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let viewModel = ContentViewModel(
        service: DefaultItemService(
            repository: SwiftDataItemRepository(context: container.mainContext)
        )
    )

    return ContentView(viewModel: viewModel)
        .modelContainer(container)
        .environment(Router())
}
