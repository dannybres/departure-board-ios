//
//  ContentView.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import SwiftUI
import CoreLocation


struct StationDestination: Hashable, Identifiable {
    let station: Station
    let boardType: BoardType
    var pendingServiceID: String?
    var id: String { "\(station.crsCode)-\(boardType.rawValue)" }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct ContentView: View {

    @Binding var deepLink: DeepLink?

    @StateObject private var viewModel = StationViewModel()
    @StateObject private var locationManager = LocationManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()
    @State private var showSettings = false
    @State private var isEditingFavourites = false
    @State private var hasPushedNearbyStation = false
    @State private var stationInfoCrs: String?
    @AppStorage(SharedDefaults.Keys.favouriteStations, store: SharedDefaults.shared) private var favouritesData: Data = Data()
    @AppStorage("nearbyStationCount") private var nearbyCount: Int = 10
    @AppStorage("mapsProvider") private var mapsProvider: String = "apple"

    private var favourites: [String] {
        (try? JSONDecoder().decode([String].self, from: favouritesData)) ?? []
    }

    private func setFavourites(_ value: [String]) {
        favouritesData = (try? JSONEncoder().encode(value)) ?? Data()
    }

    private func isFavourite(_ station: Station) -> Bool {
        favourites.contains(station.crsCode)
    }

    private func moveFavourite(from source: IndexSet, to destination: Int) {
        var current = favourites
        current.move(fromOffsets: source, toOffset: destination)
        setFavourites(current)
    }

    private func toggleFavourite(_ station: Station) {
        var current = favourites
        if let index = current.firstIndex(of: station.crsCode) {
            current.remove(at: index)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else {
            current.append(station.crsCode)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
            .prefix(nearbyCount)
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
        NavigationStack(path: $navigationPath) {
            stationListView
                .navigationTitle("Departure Board")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    NavigationStack {
                        SettingsView(viewModel: viewModel)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") { showSettings = false }
                                }
                            }
                    }
                    .tint(Theme.brand)
                }
                .sheet(item: $stationInfoCrs) { crs in
                    StationInfoView(crs: crs, onDismiss: {
                        stationInfoCrs = nil
                    }, onNavigate: { boardType in
                        if let station = StationCache.load()?.first(where: { $0.crsCode == crs }) {
                            stationInfoCrs = nil
                            navigationPath.append(StationDestination(station: station, boardType: boardType))
                        }
                    })
                }
                .navigationDestination(for: Station.self) { station in
                    DepartureBoardView(station: station, navigationPath: $navigationPath)
                }
                .navigationDestination(for: StationDestination.self) { dest in
                    DepartureBoardView(station: dest.station, initialBoardType: dest.boardType, pendingServiceID: dest.pendingServiceID, navigationPath: $navigationPath)
                }
                .onAppear { locationManager.refresh() }
                .onChange(of: scenePhase) {
                    if scenePhase == .active {
                        locationManager.refresh()
                    }
                }
                .onChange(of: locationManager.userLocation) {
                    guard let _ = locationManager.userLocation, !hasPushedNearbyStation else { return }
                    guard deepLink == nil else { return }

                    if let firstNearby = nearbyStations.first {
                        withAnimation {
                            navigationPath.append(
                                StationDestination(station: firstNearby, boardType: .departures)
                            )
                            hasPushedNearbyStation = true
                        }
                    }
                }
                .onChange(of: deepLink) {
                    guard let link = deepLink else { return }
                    deepLink = nil
                    handleDeepLink(link)
                }

        }

    }

    private var stationListView: some View {
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
                        .onMove(perform: moveFavourite)
                    } header: {
                        HStack {
                            sectionHeader("Favourites", icon: "star.fill")
                            Spacer()
                            Button(isEditingFavourites ? "Done" : "Edit") {
                                withAnimation {
                                    isEditingFavourites.toggle()
                                }
                            }
                            .font(.subheadline)
                            .textCase(nil)
                        }
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
        .environment(\.editMode, isEditingFavourites ? .constant(.active) : .constant(.inactive))
        .refreshable { viewModel.reloadFromCache() }
        .searchable(text: $searchText, prompt: "Search stations")
    }

    private func handleDeepLink(_ link: DeepLink) {
        let crs: String
        switch link {
        case .departures(let c): crs = c
        case .arrivals(let c): crs = c
        case .station(let c): crs = c
        case .service(let c, _): crs = c
        }

        guard let station = StationCache.load()?.first(where: { $0.crsCode == crs }) else { return }

        hasPushedNearbyStation = true

        // Pop to root first, then push on the next run loop so SwiftUI
        // fully tears down the old stack before creating the new view.
        navigationPath = NavigationPath()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch link {
            case .departures:
                navigationPath.append(StationDestination(station: station, boardType: .departures))
            case .arrivals:
                navigationPath.append(StationDestination(station: station, boardType: .arrivals))
            case .station:
                stationInfoCrs = station.crsCode
            case .service(_, let serviceID):
                navigationPath.append(StationDestination(station: station, boardType: .departures, pendingServiceID: serviceID))
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.brand)
            .textCase(nil)
    }

    private func distanceInMiles(to station: Station) -> Double? {
        guard let userLocation = locationManager.userLocation else { return nil }
        let stationLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
        return userLocation.distance(from: stationLocation) / 1609.344
    }

    private func openInMaps(_ station: Station) {
        if mapsProvider == "google",
           let url = URL(string: "comgooglemaps://?q=\(station.latitude),\(station.longitude)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if mapsProvider == "google",
                  let url = URL(string: "https://www.google.com/maps?q=\(station.latitude),\(station.longitude)") {
            UIApplication.shared.open(url)
        } else {
            let url = URL(string: "maps:?q=\(station.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&ll=\(station.latitude),\(station.longitude)")!
            UIApplication.shared.open(url)
        }
    }

    @ViewBuilder
    private func stationContextMenu(for station: Station) -> some View {
        Button {
            navigationPath.append(StationDestination(station: station, boardType: .departures))
        } label: {
            Label("Show Departures", systemImage: "arrow.up.right")
        }

        Button {
            navigationPath.append(StationDestination(station: station, boardType: .arrivals))
        } label: {
            Label("Show Arrivals", systemImage: "arrow.down.left")
        }

        Divider()

        Button {
            toggleFavourite(station)
        } label: {
            if isFavourite(station) {
                Label("Remove Favourite", systemImage: "star.slash")
            } else {
                Label("Add to Favourites", systemImage: "star.fill")
            }
        }

        Divider()

        Button {
            openInMaps(station)
        } label: {
            Label("Open in Maps", systemImage: "map")
        }

        Button {
            stationInfoCrs = station.crsCode
        } label: {
            Label("Station Information", systemImage: "info.circle")
        }

    }

    private func crsPill(_ code: String) -> some View {
        Text(code)
            .font(Theme.crsFont)
            .foregroundStyle(Theme.brand)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.brandSubtle, in: RoundedRectangle(cornerRadius: 4))
    }

    private func nearbyRow(_ station: Station) -> some View {
        NavigationLink(value: station) {
            HStack {
                crsPill(station.crsCode)
                VStack(alignment: .leading) {
                    Text(station.name)
                        .font(.headline)
                }
                Spacer()
                if let distance = distanceInMiles(to: station) {
                    Text(String(format: "%.1f mi", distance))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contextMenu {
            stationContextMenu(for: station)
        }
    }

    private func stationRow(_ station: Station) -> some View {
        NavigationLink(value: station) {
            HStack {
                crsPill(station.crsCode)
                VStack(alignment: .leading) {
                    Text(station.name)
                        .font(.headline)
                }
                if isFavourite(station) {
                    Spacer()
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.subheadline)
                }
            }
        }
        .contextMenu {
            stationContextMenu(for: station)
        }
    }
}
