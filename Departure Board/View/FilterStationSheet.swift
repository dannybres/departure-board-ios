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
    @Environment(\.stationNamesSmallCaps) private var stationNamesSmallCaps

    private var allStations: [Station] {
        StationCache.load() ?? []
    }

    private var favouriteStations: [Station] {
        let boards = SharedDefaults.loadFavouriteBoards()
        let crsCodes = Set(boards.compactMap { SharedDefaults.parseBoardID($0)?.crs })
        return allStations.filter { crsCodes.contains($0.crsCode) && $0.crsCode != currentStationCrs }
    }

    private var searchedFavourites: [Station] {
        if searchText.isEmpty { return favouriteStations }
        return favouriteStations.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.crsCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredStations: [Station] {
        let favCodes = Set(favouriteStations.map(\.crsCode))
        let stations = allStations.filter { $0.crsCode != currentStationCrs && !favCodes.contains($0.crsCode) }
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

                if !searchedFavourites.isEmpty {
                    Section {
                        ForEach(searchedFavourites) { station in
                            stationButton(station)
                        }
                    } header: {
                        Label("Favourites", systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.brand)
                            .textCase(nil)
                    }
                }

                Section {
                    ForEach(filteredStations) { station in
                        stationButton(station)
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

    private func stationButton(_ station: Station) -> some View {
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
                    .font(Font.body.smallCapsIfEnabled(stationNamesSmallCaps))
                    .foregroundStyle(.primary)
            }
        }
    }
}
