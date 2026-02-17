//
//  FilterStationSheet.swift
//  Departure Board
//

import SwiftUI

struct FilterStationSheet: View {

    let currentStationCrs: String
    @Binding var filterType: String
    let onSelect: (Station) -> Void

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var allStations: [Station] {
        StationCache.load() ?? []
    }

    private var filteredStations: [Station] {
        let stations = allStations.filter { $0.crsCode != currentStationCrs }
        if searchText.isEmpty { return stations }
        return stations.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.crsCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter type", selection: $filterType) {
                        Text("Calling at").tag("to")
                        Text("Coming from").tag("from")
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    ForEach(filteredStations) { station in
                        Button {
                            onSelect(station)
                        } label: {
                            HStack {
                                Text(station.crsCode)
                                    .font(Theme.crsFont)
                                    .foregroundStyle(Theme.brand)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.brandSubtle, in: RoundedRectangle(cornerRadius: 4))
                                Text(station.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                } header: {
                    Text("Stations")
                }
            }
            .searchable(text: $searchText, prompt: "Search stations")
            .navigationTitle("Filter by Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(Theme.brand)
    }
}
