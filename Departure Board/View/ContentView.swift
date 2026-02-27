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
    var filterStation: Station?
    var filterType: String?
    var id: String { "\(station.crsCode)-\(boardType.rawValue)" }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct NextServiceSheetItem: Identifiable {
    let service: Service
    let boardType: BoardType
    var id: String { service.serviceId }
}

private struct NextServicePillView: View {
    let service: Service
    let boardType: BoardType
    @State private var opacity: Double = 0
    @State private var height: CGFloat = 0
    private let targetHeight: CGFloat = 28

    var body: some View {
        let scheduled    = boardType == .departures ? service.std : service.sta
        let estimated    = boardType == .departures ? service.etd : service.eta
        let isOnTime     = estimated == "On time"
        let isDelayed    = !isOnTime && estimated != nil && !service.isCancelled
        let locationName = boardType == .departures
            ? service.destination.first?.locationName
            : service.origin.first?.locationName

        HStack(spacing: 6) {
            if let sched = scheduled {
                Text(sched)
                    .font(.system(.caption, design: .monospaced).bold())
            }
            if let loc = locationName {
                Text(loc)
                    .font(.caption)
                    .lineLimit(1)
            }
            if service.isCancelled {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            } else if isDelayed {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            Spacer(minLength: 0)
            if isDelayed, let exp = estimated {
                Text(exp)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(.orange)
            }
            if let platform = service.platform {
                Text(service.serviceType == "bus" ? platform : "Plat \(platform)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(white: 0.2), in: RoundedRectangle(cornerRadius: 3))
                    .environment(\.colorScheme, .dark)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Theme.brandSubtle, in: RoundedRectangle(cornerRadius: 7))
        .frame(height: height)
        .clipped()
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                height = targetHeight
                opacity = 1
            }
        }
    }
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
    @AppStorage(SharedDefaults.Keys.favouriteItems, store: SharedDefaults.shared) private var favouriteItemsData: Data = Data()
    @AppStorage(SharedDefaults.Keys.favouriteStations, store: SharedDefaults.shared) private var favouritesData: Data = Data()
    @AppStorage(SharedDefaults.Keys.savedFilters, store: SharedDefaults.shared) private var savedFiltersData: Data = Data()
    @AppStorage("nearbyStationCount") private var nearbyCount: Int = 10
    @AppStorage("recentFilterCount") private var recentFilterCount: Int = 3
    @AppStorage("showRecentFilters") private var showRecentFilters: Bool = true
    @AppStorage("mapsProvider") private var mapsProvider: String = "apple"
    @AppStorage("showNextServiceOnFavourites") private var showNextServiceOnFavourites: Bool = true
    @AppStorage("autoLoadMode") private var autoLoadMode: String = "nearest"
    @AppStorage("autoLoadDistanceMiles") private var autoLoadDistanceMiles: Int = 2
    @State private var nextServices: [String: BoardSummary] = [:]
    @State private var nextServiceSheetItem: NextServiceSheetItem?

    // MARK: - Unified Favourites

    private var favouriteItemIDs: [String] {
        if let items = try? JSONDecoder().decode([String].self, from: favouriteItemsData), !items.isEmpty {
            return items
        }
        // Fall back to legacy favouriteStations for migration (as departures)
        let legacy = (try? JSONDecoder().decode([String].self, from: favouritesData)) ?? []
        return legacy.map { "\($0)-departures" }
    }

    private func setFavouriteItems(_ value: [String]) {
        favouriteItemsData = (try? JSONEncoder().encode(value)) ?? Data()
        let allCodes = Set(viewModel.stations.map(\.crsCode))
        SharedDefaults.syncStationFavourites(from: value, allStationCodes: allCodes)
    }

    private var savedFilters: [SavedFilter] {
        (try? JSONDecoder().decode([SavedFilter].self, from: savedFiltersData)) ?? []
    }

    private var savedFiltersByID: [String: SavedFilter] {
        Dictionary(savedFilters.map { ($0.id, $0) }, uniquingKeysWith: { _, b in b })
    }

    // MARK: - Favourite Display

    enum FavouriteDisplayItem: Identifiable {
        case station(Station, BoardType)
        case filter(SavedFilter)

        var id: String {
            switch self {
            case .station(let s, let bt): return SharedDefaults.stationFavID(crs: s.crsCode, boardType: bt)
            case .filter(let f): return f.id
            }
        }
    }

    private var favouriteDisplayItems: [FavouriteDisplayItem] {
        let filterMap = savedFiltersByID
        return favouriteItemIDs.compactMap { itemID in
            // Try station parse first
            if let parsed = SharedDefaults.parseStationFavID(itemID),
               let station = viewModel.stations.first(where: { $0.crsCode == parsed.crs }) {
                return .station(station, parsed.boardType)
            }
            // Try filter
            if let filter = filterMap[itemID], filter.isFavourite {
                return .filter(filter)
            }
            return nil
        }
    }

    private func isStationFavourited(_ station: Station, boardType: BoardType) -> Bool {
        favouriteItemIDs.contains(SharedDefaults.stationFavID(crs: station.crsCode, boardType: boardType))
    }

    private func isAnyBoardFavourited(_ station: Station) -> Bool {
        isStationFavourited(station, boardType: .departures) || isStationFavourited(station, boardType: .arrivals)
    }

    /// Check if a station has any favourite at all (board or filter involving it)
    private func hasAnyFavourite(_ station: Station) -> Bool {
        if isAnyBoardFavourited(station) { return true }
        return savedFilters.contains { $0.isFavourite && ($0.stationCrs == station.crsCode || $0.filterCrs == station.crsCode) }
    }

    enum FavouriteEntry: Identifiable {
        case board(Station, BoardType)
        case filter(SavedFilter)

        var id: String {
            switch self {
            case .board(let s, let bt): return SharedDefaults.stationFavID(crs: s.crsCode, boardType: bt)
            case .filter(let f): return f.id
            }
        }

        var label: String {
            switch self {
            case .board(_, let bt): return bt.rawValue.capitalized
            case .filter(let f): return "\(f.boardType.rawValue.capitalized) \(f.filterLabel)"
            }
        }
    }

    private func favouritesForStation(_ station: Station) -> [FavouriteEntry] {
        var results: [FavouriteEntry] = []
        if isStationFavourited(station, boardType: .departures) {
            results.append(.board(station, .departures))
        }
        if isStationFavourited(station, boardType: .arrivals) {
            results.append(.board(station, .arrivals))
        }
        for filter in savedFilters where filter.isFavourite {
            if filter.stationCrs == station.crsCode || filter.filterCrs == station.crsCode {
                results.append(.filter(filter))
            }
        }
        return results
    }

    private func navigateToFavouriteEntry(_ entry: FavouriteEntry) {
        switch entry {
        case .board(let station, let boardType):
            navigationPath.append(StationDestination(station: station, boardType: boardType))
        case .filter(let filter):
            navigateToFilter(filter)
        }
    }

    private func moveFavourite(from source: IndexSet, to destination: Int) {
        var current = favouriteItemIDs
        current.move(fromOffsets: source, toOffset: destination)
        setFavouriteItems(current)
    }

    private func addStationFavourite(_ station: Station, boardType: BoardType) {
        var current = favouriteItemIDs
        let id = SharedDefaults.stationFavID(crs: station.crsCode, boardType: boardType)
        guard !current.contains(id) else { return }
        current.append(id)
        setFavouriteItems(current)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func removeStationFavourite(_ station: Station, boardType: BoardType) {
        var current = favouriteItemIDs
        let id = SharedDefaults.stationFavID(crs: station.crsCode, boardType: boardType)
        current.removeAll { $0 == id }
        setFavouriteItems(current)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func removeFavouriteByID(_ id: String) {
        var current = favouriteItemIDs
        current.removeAll { $0 == id }
        setFavouriteItems(current)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func toggleFilterFavourite(_ filter: SavedFilter) {
        var allFilters = savedFilters
        var currentItems = favouriteItemIDs

        if let idx = allFilters.firstIndex(where: { $0.id == filter.id }) {
            let wasFavourite = allFilters[idx].isFavourite
            allFilters[idx].isFavourite = !wasFavourite

            if wasFavourite {
                currentItems.removeAll { $0 == filter.id }
            } else {
                currentItems.append(filter.id)
            }

            if let data = try? JSONEncoder().encode(allFilters) {
                savedFiltersData = data
            }
            setFavouriteItems(currentItems)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func removeFilter(_ filter: SavedFilter) {
        var allFilters = savedFilters
        allFilters.removeAll { $0.id == filter.id }
        if let data = try? JSONEncoder().encode(allFilters) {
            savedFiltersData = data
        }
        var currentItems = favouriteItemIDs
        currentItems.removeAll { $0 == filter.id }
        setFavouriteItems(currentItems)
    }

    private func navigateToFilter(_ filter: SavedFilter) {
        if let station = viewModel.stations.first(where: { $0.crsCode == filter.stationCrs }),
           let filterStn = viewModel.stations.first(where: { $0.crsCode == filter.filterCrs }) {
            navigationPath.append(StationDestination(
                station: station,
                boardType: filter.boardType,
                filterStation: filterStn,
                filterType: filter.filterType
            ))
        }
    }

    // MARK: - Next Service Fetch

    private func fetchNextServices() async {
        guard showNextServiceOnFavourites else { return }
        let items = favouriteDisplayItems
        guard !items.isEmpty else { return }

        let pairs: [(id: String, request: BoardRequest)] = items.map { item in
            switch item {
            case .station(let station, let boardType):
                return (item.id, BoardRequest(crs: station.crsCode, type: boardType.rawValue, filterCrs: nil, filterType: nil))
            case .filter(let filter):
                return (item.id, BoardRequest(crs: filter.stationCrs, type: filter.boardType.rawValue, filterCrs: filter.filterCrs, filterType: filter.filterType))
            }
        }

        do {
            let summaries = try await StationViewModel.fetchBoards(pairs.map(\.request))
            var result: [String: BoardSummary] = [:]
            for (index, summary) in summaries.enumerated() {
                guard index < pairs.count else { break }
                result[pairs[index].id] = summary
            }
            withAnimation(.easeOut(duration: 3)) {
                nextServices = result
            }
        } catch {
            // Silent failure — next service info is supplementary
        }
    }

    // MARK: - Auto-Load

    private func resolveAutoLoadDestination() -> StationDestination? {
        switch autoLoadMode {
        case "nearest":
            guard let station = nearbyStations.first else { return nil }
            return StationDestination(station: station, boardType: .departures)
        case "favourite":
            return nearestFavouriteDestination()
        case "favouriteOrNearest":
            if let fav = nearestFavouriteDestination() { return fav }
            guard let station = nearbyStations.first else { return nil }
            return StationDestination(station: station, boardType: .departures)
        default:
            return nil
        }
    }

    /// Returns the highest-priority favourite (by list order) within the configured distance.
    private func nearestFavouriteDestination() -> StationDestination? {
        guard let userLocation = locationManager.userLocation else { return nil }
        let thresholdMetres = Double(autoLoadDistanceMiles) * 1609.344

        for item in favouriteDisplayItems {
            switch item {
            case .station(let station, let boardType):
                let loc = CLLocation(latitude: station.latitude, longitude: station.longitude)
                if userLocation.distance(from: loc) <= thresholdMetres {
                    return StationDestination(station: station, boardType: boardType)
                }
            case .filter(let filter):
                guard let station = viewModel.stations.first(where: { $0.crsCode == filter.stationCrs }) else { continue }
                let loc = CLLocation(latitude: station.latitude, longitude: station.longitude)
                if userLocation.distance(from: loc) <= thresholdMetres {
                    return StationDestination(station: station, boardType: filter.boardType, filterStation: viewModel.stations.first(where: { $0.crsCode == filter.filterCrs }), filterType: filter.filterType)
                }
            }
        }
        return nil
    }

    // MARK: - Recent Filters

    private var recentFilters: [SavedFilter] {
        savedFilters.filter { !$0.isFavourite }
    }

    // MARK: - Filtered/Computed Station Lists

    private var filteredStations: [Station] {
        if searchText.isEmpty {
            return viewModel.stations
        }
        return viewModel.stations.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.crsCode.localizedCaseInsensitiveContains(searchText)
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

    private var favouritedStationCodes: Set<String> {
        Set(favouriteItemIDs.compactMap { SharedDefaults.parseStationFavID($0)?.crs })
    }

    private var otherStations: [Station] {
        if isSearching {
            return filteredStations
        }
        let favCodes = favouritedStationCodes
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
                .sheet(item: $nextServiceSheetItem) { item in
                    NavigationStack {
                        let scheduled = item.boardType == .departures ? item.service.std : item.service.sta
                        let location = item.boardType == .departures
                            ? item.service.destination.first?.locationName
                            : item.service.origin.first?.locationName
                        ServiceDetailView(service: item.service, boardType: item.boardType, navigationPath: .constant(NavigationPath()))
                            .navigationTitle([scheduled, location].compactMap { $0 }.joined(separator: " · "))
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") { nextServiceSheetItem = nil }
                                }
                            }
                    }
                    .tint(Theme.brand)
                }
                .navigationDestination(for: Station.self) { station in
                    DepartureBoardView(station: station, navigationPath: $navigationPath)
                }
                .navigationDestination(for: StationDestination.self) { dest in
                    DepartureBoardView(station: dest.station, initialBoardType: dest.boardType, pendingServiceID: dest.pendingServiceID, initialFilterStation: dest.filterStation, initialFilterType: dest.filterType, navigationPath: $navigationPath)
                }
                .onAppear { locationManager.refresh() }
                .onChange(of: scenePhase) {
                    if scenePhase == .active {
                        locationManager.refresh()
                    }
                }
                .onChange(of: locationManager.userLocation) {
                    guard locationManager.userLocation != nil, !hasPushedNearbyStation else { return }
                    guard deepLink == nil else { return }
                    guard autoLoadMode != "off" else { return }

                    let destination = resolveAutoLoadDestination()
                    guard let destination else { return }

                    hasPushedNearbyStation = true
                    Task {
                        try? await Task.sleep(for: .milliseconds(600))
                        navigationPath.append(destination)
                    }
                }
                .onChange(of: deepLink) {
                    guard let link = deepLink else { return }
                    deepLink = nil
                    handleDeepLink(link)
                }

        }

    }

    // MARK: - Station List

    private var stationListView: some View {
        List {
            if !isSearching {
                if !favouriteDisplayItems.isEmpty {
                    Section {
                        ForEach(favouriteDisplayItems) { item in
                            switch item {
                            case .station(let station, let boardType):
                                favouriteStationRow(station, boardType: boardType, itemID: item.id)
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            removeFavouriteByID(item.id)
                                        } label: {
                                            Label("Unfavourite", systemImage: "star.slash")
                                        }
                                        .tint(.red)
                                    }
                            case .filter(let filter):
                                filterRow(filter, showStar: true)
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            toggleFilterFavourite(filter)
                                        } label: {
                                            Label("Unfavourite", systemImage: "star.slash")
                                        }
                                        .tint(.red)
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

                if showRecentFilters && !recentFilters.isEmpty {
                    Section {
                        ForEach(recentFilters) { filter in
                            filterRow(filter)
                                .swipeActions(edge: .trailing) {
                                    Button {
                                        withAnimation {
                                            removeFilter(filter)
                                        }
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                    .tint(.gray)
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        withAnimation {
                                            toggleFilterFavourite(filter)
                                        }
                                    } label: {
                                        Label("Favourite", systemImage: "star.fill")
                                    }
                                    .tint(.yellow)
                                }
                        }
                    } header: {
                        sectionHeader("Recent Filters", icon: "clock.arrow.circlepath")
                    }
                }

                if !nearbyStations.isEmpty {
                    Section {
                        ForEach(nearbyStations) { station in
                            nearbyRow(station)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        addStationFavourite(station, boardType: .departures)
                                    } label: {
                                        Label("Favourite", systemImage: "star.fill")
                                    }
                                    .tint(.yellow)
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
                        .swipeActions(edge: .leading) {
                            Button {
                                addStationFavourite(station, boardType: .departures)
                            } label: {
                                Label("Favourite", systemImage: "star.fill")
                            }
                            .tint(.yellow)
                        }
                }
            } header: {
                sectionHeader("All Stations", icon: "train.side.front.car")
            }
        }
        .environment(\.editMode, isEditingFavourites ? .constant(.active) : .constant(.inactive))
        .refreshable {
            viewModel.reloadFromCache()
            Task { await fetchNextServices() }
        }
        .task { await fetchNextServices() }
        .searchable(text: $searchText, prompt: "Search stations")
    }

    // MARK: - Deep Linking

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

        navigationPath = NavigationPath()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch link {
            case .departures:
                navigationPath.append(StationDestination(station: station, boardType: .departures))
            case .arrivals:
                navigationPath.append(StationDestination(station: station, boardType: .arrivals))
            case .station:
                stationInfoCrs = station.crsCode
            case .service(_, let serviceId):
                navigationPath.append(StationDestination(station: station, boardType: .departures, pendingServiceID: serviceId))
            }
        }
    }

    // MARK: - Helpers

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

    // MARK: - Context Menus

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

        let existingFavs = favouritesForStation(station)
        if !existingFavs.isEmpty {
            Section("Favourited") {
                ForEach(existingFavs) { fav in
                    Button {
                        navigateToFavouriteEntry(fav)
                    } label: {
                        Label(fav.label, systemImage: "star.fill")
                    }
                }
            }
        }

        Divider()

        if isStationFavourited(station, boardType: .departures) {
            Button {
                removeStationFavourite(station, boardType: .departures)
            } label: {
                Label("Remove Departures Favourite", systemImage: "star.slash")
            }
        } else {
            Button {
                addStationFavourite(station, boardType: .departures)
            } label: {
                Label("Favourite Departures", systemImage: "star.fill")
            }
        }

        if isStationFavourited(station, boardType: .arrivals) {
            Button {
                removeStationFavourite(station, boardType: .arrivals)
            } label: {
                Label("Remove Arrivals Favourite", systemImage: "star.slash")
            }
        } else {
            Button {
                addStationFavourite(station, boardType: .arrivals)
            } label: {
                Label("Favourite Arrivals", systemImage: "star.fill")
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

    @ViewBuilder
    private func favouriteStationContextMenu(for station: Station, boardType: BoardType) -> some View {
        let itemID = SharedDefaults.stationFavID(crs: station.crsCode, boardType: boardType)
        if let svc = nextServices[itemID]?.service {
            let scheduled = boardType == .departures ? svc.std : svc.sta
            let location = boardType == .departures ? svc.destination.first?.locationName : svc.origin.first?.locationName
            Section([scheduled, location].compactMap { $0 }.joined(separator: " · ")) {
                Button {
                    nextServiceSheetItem = NextServiceSheetItem(service: svc, boardType: boardType)
                } label: {
                    Label("View Service", systemImage: "train.side.front.car")
                }
            }
            Divider()
        }

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

        // Switch board type
        let otherType: BoardType = boardType == .departures ? .arrivals : .departures
        let otherID = SharedDefaults.stationFavID(crs: station.crsCode, boardType: otherType)
        let otherExists = favouriteItemIDs.contains(otherID)
        if otherExists {
            Text("\(otherType.rawValue.capitalized) already favourited")
                .foregroundStyle(.secondary)
        } else {
            Button {
                var current = favouriteItemIDs
                let oldID = SharedDefaults.stationFavID(crs: station.crsCode, boardType: boardType)
                if let idx = current.firstIndex(of: oldID) {
                    current[idx] = otherID
                }
                setFavouriteItems(current)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label("Change to \(otherType.rawValue.capitalized)", systemImage: otherType == .departures ? "arrow.up.right" : "arrow.down.left")
            }
        }

        Button {
            removeFavouriteByID(SharedDefaults.stationFavID(crs: station.crsCode, boardType: boardType))
        } label: {
            Label("Remove Favourite", systemImage: "star.slash")
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

    @ViewBuilder
    private func filterContextMenu(for filter: SavedFilter) -> some View {
        if let svc = nextServices[filter.id]?.service {
            let scheduled = filter.boardType == .departures ? svc.std : svc.sta
            let location = filter.boardType == .departures ? svc.destination.first?.locationName : svc.origin.first?.locationName
            Section([scheduled, location].compactMap { $0 }.joined(separator: " · ")) {
                Button {
                    nextServiceSheetItem = NextServiceSheetItem(service: svc, boardType: filter.boardType)
                } label: {
                    Label("View Service", systemImage: "train.side.front.car")
                }
            }
            Divider()
        }

        Button {
            navigateToFilter(filter)
        } label: {
            Label("Show Board", systemImage: "line.3.horizontal.decrease.circle")
        }

        Menu {
            Button {
                if let station = viewModel.stations.first(where: { $0.crsCode == filter.stationCrs }) {
                    navigationPath.append(StationDestination(station: station, boardType: .departures))
                }
            } label: {
                Label("Departures", systemImage: "arrow.up.right")
            }
            Button {
                if let station = viewModel.stations.first(where: { $0.crsCode == filter.stationCrs }) {
                    navigationPath.append(StationDestination(station: station, boardType: .arrivals))
                }
            } label: {
                Label("Arrivals", systemImage: "arrow.down.left")
            }
            Button {
                stationInfoCrs = filter.stationCrs
            } label: {
                Label("Station Info", systemImage: "info.circle")
            }
            if let station = viewModel.stations.first(where: { $0.crsCode == filter.stationCrs }) {
                Button {
                    openInMaps(station)
                } label: {
                    Label("Open in Maps", systemImage: "map")
                }
            }
        } label: {
            Label(filter.stationName, systemImage: "building.2")
        }

        Menu {
            Button {
                if let station = viewModel.stations.first(where: { $0.crsCode == filter.filterCrs }) {
                    navigationPath.append(StationDestination(station: station, boardType: .departures))
                }
            } label: {
                Label("Departures", systemImage: "arrow.up.right")
            }
            Button {
                if let station = viewModel.stations.first(where: { $0.crsCode == filter.filterCrs }) {
                    navigationPath.append(StationDestination(station: station, boardType: .arrivals))
                }
            } label: {
                Label("Arrivals", systemImage: "arrow.down.left")
            }
            Button {
                stationInfoCrs = filter.filterCrs
            } label: {
                Label("Station Info", systemImage: "info.circle")
            }
            if let station = viewModel.stations.first(where: { $0.crsCode == filter.filterCrs }) {
                Button {
                    openInMaps(station)
                } label: {
                    Label("Open in Maps", systemImage: "map")
                }
            }
        } label: {
            Label(filter.filterName, systemImage: "building.2")
        }

        Divider()

        Button {
            toggleFilterFavourite(filter)
        } label: {
            if filter.isFavourite {
                Label("Remove Favourite", systemImage: "star.slash")
            } else {
                Label("Add to Favourites", systemImage: "star.fill")
            }
        }

        if !filter.isFavourite {
            Button {
                withAnimation {
                    removeFilter(filter)
                }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    // MARK: - Row Views

    private func crsPill(_ code: String) -> some View {
        Text(code)
            .font(Theme.crsFont)
            .foregroundStyle(Theme.brand)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.brandSubtle, in: RoundedRectangle(cornerRadius: 4))
    }

    private func filterCrsPill(_ filter: SavedFilter) -> some View {
        let leftCrs = filter.filterType == "from" ? filter.filterCrs : filter.stationCrs
        let rightCrs = filter.filterType == "from" ? filter.stationCrs : filter.filterCrs
        return HStack(spacing: 4) {
            Text(leftCrs)
                .font(Theme.crsFont)
                .foregroundStyle(Theme.brand)
            Image(systemName: "arrow.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
            Text(rightCrs)
                .font(Theme.crsFont)
                .foregroundStyle(Theme.brand)
        }
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
                if hasAnyFavourite(station) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Theme.brand)
                        .font(.caption)
                }
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
                if hasAnyFavourite(station) {
                    Spacer()
                    Image(systemName: "star.fill")
                        .foregroundStyle(Theme.brand)
                        .font(.caption)
                }
            }
        }
        .contextMenu {
            stationContextMenu(for: station)
        }
    }

    private func favouriteStationRow(_ station: Station, boardType: BoardType, itemID: String) -> some View {
        NavigationLink(value: StationDestination(station: station, boardType: boardType)) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    crsPill(station.crsCode)
                    VStack(alignment: .leading) {
                        Text(station.name)
                            .font(.headline)
                        Text(boardType.rawValue.capitalized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: boardType == .departures ? "arrow.up.right" : "arrow.down.left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if showNextServiceOnFavourites {
                    nextServicePill(id: itemID, boardType: boardType)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .contextMenu {
            favouriteStationContextMenu(for: station, boardType: boardType)
        }
    }

    @ViewBuilder
    private func nextServicePill(id: String, boardType: BoardType) -> some View {
        if let svc = nextServices[id]?.service {
            NextServicePillView(service: svc, boardType: boardType)
        }
    }

    private func filterRow(_ filter: SavedFilter, showStar: Bool = false) -> some View {
        Button {
            navigateToFilter(filter)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    filterCrsPill(filter)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(filter.stationName)
                            .font(.headline)
                        Text("\(filter.filterLabel) · \(filter.boardType.rawValue.capitalized)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if showStar {
                        Image(systemName: "arrow.right.arrow.left")
                            .foregroundStyle(Theme.brand)
                            .font(.caption)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                if showStar && showNextServiceOnFavourites {
                    nextServicePill(id: filter.id, boardType: filter.boardType)
                        .padding(.trailing, 20)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(.primary)
        .contextMenu {
            filterContextMenu(for: filter)
        }
    }
}
