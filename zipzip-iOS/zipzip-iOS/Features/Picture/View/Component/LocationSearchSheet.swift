//
//  LocationSearchSheet.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import MapKit
import SQLiteData
import SwiftUI

struct LocationSearchSheet: View {
    @Binding var selected: String
    let onCancel: () -> Void
    let onDone: () -> Void

    @Dependency(\.photoFilterOptions) private var filterOptions
    @State private var locations: [String] = []
    @State private var query = ""
    @State private var searchModel = LocationSearchModel()

    var body: some View {
        BottomSheet(
            leftItem: {
                headerButton(title: "취소", action: onCancel)
            },
            rightItem: {
                headerButton(title: "완료", action: onDone)
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                TextInput("장소 검색", text: $query, style: .search)

                if query.isEmpty {
                    savedChips
                } else {
                    resultList
                }
            }
            .padding(.horizontal, 16)
        }
        .onChange(of: query) { _, newValue in
            searchModel.update(newValue)
        }
        .task { await loadLocations() }
    }

    private func headerButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.b1_sb)
                .foregroundStyle(.white00)
                .frame(width: 72, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var savedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(locations, id: \.self) { location in
                    Button {
                        select(location)
                    } label: {
                        Text(location)
                            .font(.b2_sb)
                            .foregroundStyle(.grey70)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.grey800, in: .rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchModel.results, id: \.self) { result in
                    Button {
                        select(result.title)
                    } label: {
                        resultCard(title: result.title, subtitle: result.subtitle)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func resultCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.t3_sb)
                .foregroundStyle(.white00)
            Text(subtitle)
                .font(.b3_md)
                .foregroundStyle(.grey400)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.grey700)
                .frame(height: 1)
        }
        .contentShape(.rect)
    }

    private func select(_ location: String) {
        selected = location
        query = location
    }

    private func loadLocations() async {
        guard let options = try? await filterOptions.load() else { return }
        locations = Array(options.locations.prefix(10))
    }
}

#Preview {
    LocationSearchSheet(
        selected: .constant("오사카"),
        onCancel: {},
        onDone: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(.black)
}
