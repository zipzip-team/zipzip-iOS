//
//  AlbumFolder.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

enum AlbumFolderState: Equatable {
    case plain
    case highlighted
    case selected(count: Int)
    case deselected
}

struct AlbumFolder<Slot: View>: View {
    var state: AlbumFolderState = .plain
    @ViewBuilder var slot: () -> Slot

    private var folderImage: ImageResource {
        switch state {
        case .highlighted, .selected: .albumFolderSelected
        default: .albumFolder
        }
    }

    var body: some View {
        ZStack {
            Image(folderImage)
                .resizable()
                .frame(width: 170, height: 152)

            slot()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.top, 32)
                .transaction { transaction in
                    transaction.disablesAnimations = true
                    transaction.animation = nil
                }
        }
        .frame(width: 170, height: 152)
        .overlay(alignment: .bottomTrailing) {
            badge
                .padding(8)
        }
    }

    @ViewBuilder private var badge: some View {
        switch state {
        case .plain, .highlighted:
            EmptyView()
        case .deselected:
            Indicator(status: .default)
        case let .selected(count):
            Indicator(title: "\(count)", status: .selected)
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        AlbumFolder(state: .plain) { PhotoGroup() }
        AlbumFolder(state: .selected(count: 22)) { PhotoGroup() }
        AlbumFolder(state: .deselected) { PhotoGroup() }
    }
    .padding()
    .background(.orange30)
}
