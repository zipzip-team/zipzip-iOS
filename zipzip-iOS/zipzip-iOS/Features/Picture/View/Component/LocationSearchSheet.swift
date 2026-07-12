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
    let onDone: (String, Double?, Double?) -> Void

    @Dependency(\.photoFilterOptions) private var filterOptions
    @State private var locations: [String] = []
    @State private var query = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var searchModel = LocationSearchModel()

    var body: some View {
        BottomSheet(
            leftItem: {
                BottomSheetCloseButton(action: onCancel)
            },
            rightItem: {
                headerButton(title: "완료") {
                    onDone(selected, selectedCoordinate?.latitude, selectedCoordinate?.longitude)
                }
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
            .padding(.vertical, 4)
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
                        selectSaved(location)
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
                        selectResult(result)
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

    private func selectSaved(_ location: String) {
        selected = location
        query = location
        selectedCoordinate = nil
    }

    private func selectResult(_ result: MKLocalSearchCompletion) {
        selected = result.title
        query = result.title
        selectedCoordinate = nil
        Task { await resolveCoordinate(for: result) }
    }

    private func resolveCoordinate(for completion: MKLocalSearchCompletion) async {
        let request = MKLocalSearch.Request(completion: completion)
        let response = try? await MKLocalSearch(request: request).start()
        guard let coordinate = response?.mapItems.first?.placemark.coordinate else { return }
        selectedCoordinate = coordinate
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
        onDone: { _, _, _ in }
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(.black)
}
