//
//  ContentView.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import SwiftUI
import CoreLocation

struct ContentView: View {

    @StateObject private var viewModel = StationViewModel()
    @StateObject private var locationManager = LocationManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var searchText = ""
    @AppStorage("favouriteStations") private var favouritesData: Data = Data()

    private var favourites: [String] {
        (try? JSONDecoder().decode([String].self, from: favouritesData)) ?? []
    }

    private func setFavourites(_ value: [String]) {
        favouritesData = (try? JSONEncoder().encode(value)) ?? Data()
    }

    private func isFavourite(_ station: Station) -> Bool {
        favourites.contains(station.crsCode)
    }

    private func toggleFavourite(_ station: Station) {
        var current = favourites
        if let index = current.firstIndex(of: station.crsCode) {
            current.remove(at: index)
        } else {
            current.append(station.crsCode)
        }
        setFavourites(current)
    }

    private var filteredStations: [Station] {
        if searchText.isEmpty {
            return viewModel.stations
        }
        return viewModel.stations.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.crsCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var favouriteStations: [Station] {
        let favCodes = favourites
        return favCodes.compactMap { code in
            filteredStations.first { $0.crsCode == code }
        }
    }

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    private var nearbyStations: [Station] {
        guard let userLocation = locationManager.userLocation else { return [] }
        return viewModel.stations
            .sorted {
                let loc0 = CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                let loc1 = CLLocation(latitude: $1.latitude, longitude: $1.longitude)
                return loc0.distance(from: userLocation) < loc1.distance(from: userLocation)
            }
            .prefix(10)
            .map { $0 }
    }

    private var otherStations: [Station] {
        if isSearching {
            return filteredStations
        }
        let favCodes = Set(favourites)
        let nearbyCodes = Set(nearbyStations.map(\.crsCode))
        return viewModel.stations.filter {
            !favCodes.contains($0.crsCode) && !nearbyCodes.contains($0.crsCode)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !isSearching {
                    if !favouriteStations.isEmpty {
                        Section {
                            ForEach(favouriteStations) { station in
                                stationRow(station)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            toggleFavourite(station)
                                        } label: {
                                            Label("Unfavourite", systemImage: "star.slash")
                                        }
                                    }
                            }
                        } header: {
                            sectionHeader("Favourites", icon: "star.fill")
                        }
                    }

                    if !nearbyStations.isEmpty {
                        Section {
                            ForEach(nearbyStations) { station in
                                nearbyRow(station)
                                    .swipeActions(edge: .trailing) {
                                        if isFavourite(station) {
                                            Button(role: .destructive) {
                                                toggleFavourite(station)
                                            } label: {
                                                Label("Unfavourite", systemImage: "star.slash")
                                            }
                                        } else {
                                            Button {
                                                toggleFavourite(station)
                                            } label: {
                                                Label("Favourite", systemImage: "star.fill")
                                            }
                                            .tint(.yellow)
                                        }
                                    }
                            }
                        } header: {
                            sectionHeader("Nearby", icon: "location.fill")
                        }
                    }
                }

                Section {
                    ForEach(otherStations) { station in
                        stationRow(station)
                            .swipeActions(edge: .trailing) {
                                if isFavourite(station) {
                                    Button(role: .destructive) {
                                        toggleFavourite(station)
                                    } label: {
                                        Label("Unfavourite", systemImage: "star.slash")
                                    }
                                } else {
                                    Button {
                                        toggleFavourite(station)
                                    } label: {
                                        Label("Favourite", systemImage: "star.fill")
                                    }
                                    .tint(.yellow)
                                }
                            }
                    }
                } header: {
                    sectionHeader("All Stations", icon: "train.side.front.car")
                }
            }
            .refreshable {
                viewModel.reloadFromCache()
            }
            .searchable(text: $searchText, prompt: "Search stations")
            .navigationTitle("Stations")
            .navigationDestination(for: Station.self) { station in
                DepartureBoardView(station: station)
            }
            .onAppear {
                locationManager.refresh()
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    locationManager.refresh()
                }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
    }

    private func distanceInMiles(to station: Station) -> Double? {
        guard let userLocation = locationManager.userLocation else { return nil }
        let stationLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
        return userLocation.distance(from: stationLocation) / 1609.344
    }

    private func nearbyRow(_ station: Station) -> some View {
        NavigationLink(value: station) {
            HStack {
                VStack(alignment: .leading) {
                    Text(station.name)
                        .font(.headline)
                    Text(station.crsCode)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let distance = distanceInMiles(to: station) {
                    Text(String(format: "%.1f mi", distance))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func stationRow(_ station: Station) -> some View {
        NavigationLink(value: station) {
            HStack {
                VStack(alignment: .leading) {
                    Text(station.name)
                        .font(.headline)
                    Text(station.crsCode)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if isFavourite(station) {
                    Spacer()
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.subheadline)
                }
            }
        }
    }
}
