//
//  ContentView.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import SwiftUI
import CoreLocation
import Combine


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

private struct SplitFlapText: View {
    let text: String
    let trigger: Int
    let animated: Bool

    @State private var displayed: String
    @State private var animationTask: Task<Void, Never>?

    init(_ text: String, trigger: Int, animated: Bool = true) {
        self.text = text
        self.trigger = trigger
        self.animated = animated
        _displayed = State(initialValue: text)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Text(text).opacity(0)
            Text(displayed)
        }
        .onChange(of: trigger) {
            guard animated else { displayed = text; return }
            animationTask?.cancel()
            animationTask = Task { await animate(to: text) }
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
            displayed = text
        }
    }

    // Returns the sequence of characters a position cycles through before landing.
    // Uppercase: ·→A→B→…→target   Lowercase: ·→a→b→…→target
    // Digit:     ·→0→1→…→target   Other: snaps immediately
    private static func sequence(for char: Character) -> [Character] {
        let v = char.unicodeScalars.first!.value
        let blank = Character("·")
        switch v {
        case 65...90:  return [blank] + (65...v).map { Character(UnicodeScalar($0)!) }
        case 97...122: return [blank] + (97...v).map { Character(UnicodeScalar($0)!) }
        case 48...57:  return [blank] + (48...v).map { Character(UnicodeScalar($0)!) }
        default:       return [char]
        }
    }

    @MainActor
    private func animate(to target: String) async {
        let chars = Array(target)
        let n = chars.count
        guard n > 0 else { displayed = target; return }

        let seqs = chars.map { Self.sequence(for: $0) }
        displayed = String(repeating: "·", count: n)

        // staggerMs: delay before each successive character starts cycling
        // cycleMs:   time between frames within a character's sequence
        let staggerMs = 60
        let cycleMs   = 40

        var elapsed = 0
        while !Task.isCancelled {
            var frame = Array(repeating: Character("·"), count: n)
            var allDone = true

            for i in 0..<n {
                let start = i * staggerMs
                if elapsed < start {
                    frame[i] = "·"
                    allDone = false
                } else {
                    let step = (elapsed - start) / cycleMs
                    let seq = seqs[i]
                    if step >= seq.count - 1 {
                        frame[i] = chars[i]
                    } else {
                        frame[i] = seq[step]
                        allDone = false
                    }
                }
            }

            displayed = String(frame)
            if allDone { break }
            try? await Task.sleep(for: .milliseconds(cycleMs))
            elapsed += cycleMs
        }

        displayed = target
    }
}

private struct NextServicePillView: View {
    enum ContentState: Equatable {
        case loading
        case failed
        case empty
        case service(Service, BoardType)
    }

    let state: ContentState
    let refreshID: Int
    @Environment(\.stationNamesSmallCaps) private var stationNamesSmallCaps
    @AppStorage("splitFlapRefresh") private var splitFlapRefresh: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            switch state {
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.55)
                    .frame(width: 12, height: 12)
                Text("Checking...")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)

            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("Couldn't load")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)

            case .empty:
                Image(systemName: "tram.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("No services right now")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)

            case .service(let service, let boardType):
                let scheduled    = boardType == .departures ? service.std : service.sta
                let estimated    = boardType == .departures ? service.etd : service.eta
                let isOnTime     = estimated == "On time"
                let isDelayed    = !isOnTime && estimated != nil && !service.isCancelled
                let locationName = boardType == .departures
                    ? service.destination.first?.locationName
                    : service.origin.first?.locationName

                if let sched = scheduled {
                    SplitFlapText(sched, trigger: refreshID, animated: splitFlapRefresh)
                        .font(.system(.caption2, design: .monospaced).bold())
                }
                if let loc = locationName {
                    SplitFlapText(loc, trigger: refreshID, animated: splitFlapRefresh)
                        .font(Font.caption2.smallCapsIfEnabled(stationNamesSmallCaps))
                        .lineLimit(1)
                }
                if service.isCancelled {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption2)
                } else if isDelayed {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.orange)
                        .font(.caption2)
                }
                Spacer(minLength: 0)
                if isDelayed, let exp = estimated {
                    Text(exp)
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(.orange)
                }
                if let platform = service.platform {
                    Text(service.serviceType == "bus" ? platform : "Plat \(platform)")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(white: 0.2), in: RoundedRectangle(cornerRadius: 3))
                        .environment(\.colorScheme, .dark)
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Theme.brandSubtle, in: RoundedRectangle(cornerRadius: 6))
        .animation(.easeOut(duration: 0.25), value: state)
    }
}

private struct NextServiceStore {
    var summaries: [String: BoardSummary] = [:]
    var failedIDs: Set<String> = []
    var refreshIDs: [String: Int] = [:]
    var sheetItem: NextServiceSheetItem? = nil
    var lastUpdate: Date? = nil
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
    @State private var cachedNearbyStations: [Station] = []
    @State private var stationInfoCrs: String?
    @AppStorage(SharedDefaults.Keys.favouriteBoards, store: SharedDefaults.shared) private var favouriteBoardsData: Data = Data()
    @AppStorage(SharedDefaults.Keys.recentFilters, store: SharedDefaults.shared) private var recentFiltersData: Data = Data()
    @AppStorage("nearbyStationCount") private var nearbyCount: Int = 5
    @AppStorage("recentFilterCount") private var recentFilterCount: Int = 3
    @AppStorage("showRecentFilters") private var showRecentFilters: Bool = true
    @AppStorage("mapsProvider") private var mapsProvider: String = "apple"
    @AppStorage("showNextServiceOnFavourites") private var showNextServiceOnFavourites: Bool = true
    @AppStorage("nextServiceTappable") private var nextServiceTappable: Bool = false
    @AppStorage("splitFlapRefresh") private var splitFlapRefresh: Bool = false
    @AppStorage("stationNamesSmallCaps") private var stationNamesSmallCaps: Bool = false
    @AppStorage("autoLoadMode") private var autoLoadMode: String = "off"
    @AppStorage("autoLoadDistanceMiles") private var autoLoadDistanceMiles: Int = 2
    @State private var nextServiceStore = NextServiceStore()
    @State private var tickDate = Date()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedStation: StationDestination?
    @State private var selectedService: Service?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // MARK: - Unified Favourites

    private var favouriteBoardIDs: [String] {
        (try? JSONDecoder().decode([String].self, from: favouriteBoardsData)) ?? []
    }

    private func setFavouriteBoards(_ value: [String]) {
        favouriteBoardsData = (try? JSONEncoder().encode(value)) ?? Data()
        let allCodes = Set(viewModel.stations.map(\.crsCode))
        SharedDefaults.syncStationFavourites(from: value, allStationCodes: allCodes)
    }

    // MARK: - Favourite Display

    enum FavouriteDisplayItem: Identifiable {
        case station(Station, BoardType)
        case filter(ParsedBoardID, Station, Station) // parsed, mainStation, filterStation

        var id: String {
            switch self {
            case .station(let s, let bt): return SharedDefaults.boardID(crs: s.crsCode, boardType: bt)
            case .filter(let p, _, _): return p.id
            }
        }

        var label: String {
            switch self {
            case .station(_, let bt): return bt.rawValue.capitalized
            case .filter(let p, _, let fs):
                return "\(p.boardType.rawValue.capitalized) \(p.filterType == "to" ? "→ \(fs.name)" : "← \(fs.name)")"
            }
        }
    }

    private var favouriteDisplayItems: [FavouriteDisplayItem] {
        favouriteBoardIDs.compactMap { id in
            guard let parsed = SharedDefaults.parseBoardID(id),
                  let station = viewModel.stations.first(where: { $0.crsCode == parsed.crs }) else { return nil }
            if let filterCrs = parsed.filterCrs, let filterType = parsed.filterType {
                guard let filterStation = viewModel.stations.first(where: { $0.crsCode == filterCrs }) else { return nil }
                return .filter(ParsedBoardID(crs: parsed.crs, boardType: parsed.boardType, filterCrs: filterCrs, filterType: filterType), station, filterStation)
            }
            return .station(station, parsed.boardType)
        }
    }

    private func isStationFavourited(_ station: Station, boardType: BoardType) -> Bool {
        favouriteBoardIDs.contains(SharedDefaults.boardID(crs: station.crsCode, boardType: boardType))
    }

    private func isAnyBoardFavourited(_ station: Station) -> Bool {
        isStationFavourited(station, boardType: .departures) || isStationFavourited(station, boardType: .arrivals)
    }

    private func hasAnyFavourite(_ station: Station) -> Bool {
        favouriteBoardIDs.contains {
            guard let parsed = SharedDefaults.parseBoardID($0) else { return false }
            return parsed.crs == station.crsCode || parsed.filterCrs == station.crsCode
        }
    }

    private func favouritesForStation(_ station: Station) -> [FavouriteDisplayItem] {
        favouriteDisplayItems.filter { item in
            switch item {
            case .station(let s, _): return s.crsCode == station.crsCode
            case .filter(_, let s, let fs): return s.crsCode == station.crsCode || fs.crsCode == station.crsCode
            }
        }
    }

    private func navigateToFavouriteEntry(_ entry: FavouriteDisplayItem) {
        switch entry {
        case .station(let station, let boardType):
            navigate(to: StationDestination(station: station, boardType: boardType))
        case .filter(let parsed, let station, let filterStation):
            navigate(to: StationDestination(station: station, boardType: parsed.boardType, filterStation: filterStation, filterType: parsed.filterType))
        }
    }

    private func moveFavourite(from source: IndexSet, to destination: Int) {
        var current = favouriteBoardIDs
        current.move(fromOffsets: source, toOffset: destination)
        setFavouriteBoards(current)
    }

    private func addStationFavourite(_ station: Station, boardType: BoardType) {
        var current = favouriteBoardIDs
        let id = SharedDefaults.boardID(crs: station.crsCode, boardType: boardType)
        guard !current.contains(id) else { return }
        current.append(id)
        setFavouriteBoards(current)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task { await fetchNextServices() }
    }

    private func removeStationFavourite(_ station: Station, boardType: BoardType) {
        var current = favouriteBoardIDs
        let id = SharedDefaults.boardID(crs: station.crsCode, boardType: boardType)
        current.removeAll { $0 == id }
        setFavouriteBoards(current)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func removeFavouriteByID(_ id: String) {
        var current = favouriteBoardIDs
        current.removeAll { $0 == id }
        setFavouriteBoards(current)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func addFilterToFavourites(id: String) {
        SharedDefaults.removeRecentFilter(id: id)
        var boards = favouriteBoardIDs
        guard !boards.contains(id) else { return }
        boards.append(id)
        setFavouriteBoards(boards)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task { await fetchNextServices() }
    }

    private func removeFilterFromFavourites(id: String) {
        var boards = favouriteBoardIDs
        boards.removeAll { $0 == id }
        setFavouriteBoards(boards)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// True when the window is too narrow to show sidebar + content side-by-side.
    /// 1024pt is Apple's standard breakpoint for 3-column layouts.
    private var isSidebarOverlaying: Bool {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
        let width = scene?.coordinateSpace.bounds.width ?? 0
        return width < 1024
    }

    private func navigate(to destination: StationDestination) {
        if horizontalSizeClass == .regular {
            selectedStation = destination
            selectedService = nil
        } else {
            navigationPath.append(destination)
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
            case .filter(let parsed, _, _):
                return (item.id, BoardRequest(crs: parsed.crs, type: parsed.boardType.rawValue, filterCrs: parsed.filterCrs, filterType: parsed.filterType))
            }
        }

        // Items with no existing data — these are the ones that need to show .failed on timeout
        let uncachedIDs = Set(pairs.map(\.id)).filter { nextServiceStore.summaries[$0] == nil }
        // Clear any previous failed state so they show "Checking..." while retrying
        if !uncachedIDs.isEmpty {
            withAnimation { nextServiceStore.failedIDs.subtract(uncachedIDs) }
        }

        do {
            let summaries = try await withThrowingTaskGroup(of: [BoardSummary].self) { group in
                group.addTask { try await StationViewModel.fetchBoards(pairs.map(\.request)) }
                group.addTask {
                    try await Task.sleep(for: .seconds(10))
                    throw CancellationError()
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            var result: [String: BoardSummary] = [:]
            for (index, summary) in summaries.enumerated() {
                guard index < pairs.count else { break }
                result[pairs[index].id] = summary
            }
            // Only trigger split-flap for items that already had data and it changed.
            // Items with no previous data (first load / after clear) animate via the
            // trigger=0 appearance animation — no need to fire a second sequential trigger.
            let changedIDs: [String] = pairs.compactMap { pair in
                guard nextServiceStore.summaries[pair.id] != nil else { return nil }
                let oldID = nextServiceStore.summaries[pair.id]?.service?.serviceId
                let newID = result[pair.id]?.service?.serviceId
                return oldID != newID ? pair.id : nil
            }

            withAnimation(.easeOut(duration: 0.35)) {
                nextServiceStore.summaries = result
                nextServiceStore.failedIDs.subtract(Set(pairs.map(\.id)))
            }
            nextServiceStore.lastUpdate = Date()

            // Trigger split-flap animation for changed items one at a time
            if splitFlapRefresh && !changedIDs.isEmpty {
                Task { @MainActor in
                    for (index, itemID) in changedIDs.enumerated() {
                        if index > 0 { try? await Task.sleep(for: .seconds(2)) }
                        nextServiceStore.refreshIDs[itemID, default: 0] += 1
                    }
                }
            }
        } catch {
            // On timeout or network failure, mark uncached items as failed so the
            // pill shows "Couldn't load" rather than staying on "Checking..." forever.
            // Items that already have cached data keep showing their last known service.
            if !uncachedIDs.isEmpty {
                withAnimation { nextServiceStore.failedIDs.formUnion(uncachedIDs) }
            }
        }
    }

    private var fuzzyUpdateLabel: String? {
        guard let updated = nextServiceStore.lastUpdate else { return nil }
        return Self.fuzzyLabel(from: updated, tick: tickDate)
    }

    static func fuzzyLabel(from updated: Date, tick: Date) -> String {
        let seconds = Int(tick.timeIntervalSince(updated))
        switch seconds {
        case ..<8:    return "Updated just now"
        case 8..<12:  return "Updated about 10s ago"
        case 12..<17: return "Updated about 15s ago"
        case 17..<22: return "Updated about 20s ago"
        case 22..<27: return "Updated about 25s ago"
        case 27..<32: return "Updated about 30s ago"
        case 32..<37: return "Updated about 35s ago"
        case 37..<42: return "Updated about 40s ago"
        case 42..<47: return "Updated about 45s ago"
        case 47..<52: return "Updated about 50s ago"
        case 52..<72: return "Updated about a minute ago"
        case 72..<92: return "Updated about a minute 20s ago"
        case 92..<112: return "Updated about a minute 40s ago"
        default:
            let mins = (seconds + 50) / 60
            return "Updated about \(mins) minutes ago"
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
            case .filter(let parsed, let station, let filterStation):
                let loc = CLLocation(latitude: station.latitude, longitude: station.longitude)
                if userLocation.distance(from: loc) <= thresholdMetres {
                    return StationDestination(station: station, boardType: parsed.boardType, filterStation: filterStation, filterType: parsed.filterType)
                }
            }
        }
        return nil
    }

    // MARK: - Recent Filters

    private var recentFilters: [ParsedBoardID] {
        let ids = (try? JSONDecoder().decode([String].self, from: recentFiltersData)) ?? []
        return ids.compactMap { SharedDefaults.parseBoardID($0) }
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

    private var exactCrsMatch: Station? {
        guard searchText.count == 3 else { return nil }
        return viewModel.stations.first { $0.crsCode.uppercased() == searchText.uppercased() }
    }

    private var nearbyStations: [Station] { cachedNearbyStations }

    private func updateNearbyStations() {
        guard let userLocation = locationManager.userLocation, !viewModel.stations.isEmpty else {
            cachedNearbyStations = []
            return
        }
        cachedNearbyStations = viewModel.stations
            .sorted {
                let loc0 = CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                let loc1 = CLLocation(latitude: $1.latitude, longitude: $1.longitude)
                return loc0.distance(from: userLocation) < loc1.distance(from: userLocation)
            }
            .prefix(nearbyCount)
            .map { $0 }
    }

    private var favouritedStationCodes: Set<String> {
        Set(favouriteBoardIDs.compactMap { SharedDefaults.parseBoardID($0)?.crs })
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
        Group {
            if horizontalSizeClass == .regular {
                padBody
            } else {
                phoneBody
            }
        }
        .environment(\.stationNamesSmallCaps, stationNamesSmallCaps)
    }

    // MARK: - Phone Layout

    private var phoneBody: some View {
        NavigationStack(path: $navigationPath) {
            stationListView
                .navigationTitle("Departure Board")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showSettings = true } label: { Image(systemName: "gearshape") }
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
                .sheet(item: $nextServiceStore.sheetItem) { item in
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
                                    Button("Done") { nextServiceStore.sheetItem = nil }
                                }
                            }
                    }
                    .tint(Theme.brand)
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

    // MARK: - iPad Layout

    private var padBody: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigationStack {
                padStationListView
                    .navigationTitle("Departure Board")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showSettings = true } label: { Image(systemName: "gearshape") }
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
                                navigate(to: StationDestination(station: station, boardType: boardType))
                            }
                        })
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
                            selectedStation = destination
                        }
                    }
                    .onChange(of: deepLink) {
                        guard let link = deepLink else { return }
                        deepLink = nil
                        handleDeepLink(link)
                    }
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 420)
            .onChange(of: selectedStation) {
                guard selectedStation != nil else { return }
                if isSidebarOverlaying { columnVisibility = .doubleColumn }
            }
        } content: {
            Group {
                if let dest = selectedStation {
                    DepartureBoardView(
                        station: dest.station,
                        initialBoardType: dest.boardType,
                        pendingServiceID: dest.pendingServiceID,
                        initialFilterStation: dest.filterStation,
                        initialFilterType: dest.filterType,
                        selectedService: $selectedService,
                        onNavigateToStation: { navigate(to: $0) },
                        navigationPath: $navigationPath
                    )
                    .id(dest.id)
                } else {
                    ContentUnavailableView("Select a Station", systemImage: "tram.fill", description: Text("Choose a station from the list to view its board"))
                }
            }
            .navigationSplitViewColumnWidth(min: 430, ideal: 540)
        } detail: {
            Group {
                if let service = selectedService, let dest = selectedStation {
                    ServiceDetailView(
                        service: service,
                        boardType: dest.boardType,
                        navigationPath: $navigationPath,
                        onNavigateToStation: { navigate(to: $0) }
                    )
                    .id(service.serviceId)
                } else {
                    ContentUnavailableView("Select a Service", systemImage: "train.side.front.car", description: Text("Choose a service from the board to view its details"))
                }
            }
        }
    }

    // MARK: - Station List

    // Shared list modifiers applied to both phone and pad list containers
    private func applyStationListModifiers<V: View>(_ list: V) -> some View {
        list
            .listStyle(.insetGrouped)
            .scrollContentBackground(horizontalSizeClass == .regular ? .hidden : .visible)
            .background(horizontalSizeClass == .regular ? Color(UIColor.systemGroupedBackground) : Color.clear)
            .environment(\.editMode, isEditingFavourites ? .constant(.active) : .constant(.inactive))
            .refreshable {
                viewModel.reloadFromCache()
                Task { await fetchNextServices() }
            }
            .onReceive(Timer.publish(every: 10, on: .main, in: .common).autoconnect()) { _ in
                tickDate = Date()
            }
            .task {
                await fetchNextServices()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    await fetchNextServices()
                }
            }
            .onChange(of: locationManager.userLocation) { updateNearbyStations() }
            .onChange(of: viewModel.stations) { updateNearbyStations() }
            .searchable(text: $searchText, prompt: "Search stations")
    }

    // iPad: List with selection binding so NavigationLink drives the split view content column
    var padStationListView: some View {
        applyStationListModifiers(List(selection: $selectedStation) {
            stationListRows
        })
    }

    // iPhone / compact: plain List so NavigationLink pushes onto the NavigationStack
    private var stationListView: some View {
        applyStationListModifiers(List {
            stationListRows
        })
    }

    @ViewBuilder
    private var stationListRows: some View {
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
                        case .filter(let parsed, _, _):
                            filterRow(parsed, showStar: true)
                                .swipeActions(edge: .trailing) {
                                    Button {
                                        removeFilterFromFavourites(id: parsed.id)
                                    } label: {
                                        Label("=noUnfavourite", systemImage: "star.slash")
                                    }
                                    .tint(.red)
                                }
                        }
                    }
                    .onMove(perform: moveFavourite)
                } header: {
                    HStack {
                        sectionHeader("Favourites", icon: "star.fill")
                        if showNextServiceOnFavourites, let label = fuzzyUpdateLabel {
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .textCase(nil)
                        }
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
                    ForEach(recentFilters) { parsed in
                        filterRow(parsed)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    withAnimation {
                                        SharedDefaults.removeRecentFilter(id: parsed.id)
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .tint(.gray)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    withAnimation {
                                        addFilterToFavourites(id: parsed.id)
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

        if let match = exactCrsMatch {
            Section {
                NavigationLink(value: StationDestination(station: match, boardType: .departures)) {
                    HStack(spacing: 12) {
                        Text(match.crsCode)
                            .font(Theme.crsFont)
                            .foregroundStyle(Theme.brand)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.brand.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(match.name)
                                .font(Font.headline.smallCapsIfEnabled(stationNamesSmallCaps))
                            Text("Exact CRS match")
                                .font(.caption)
                                .foregroundStyle(Theme.brand)
                        }
                        Spacer()
                        if hasAnyFavourite(match) {
                            Image(systemName: "star.fill").foregroundStyle(Theme.brand).font(.caption)
                        }
                        if horizontalSizeClass == .regular {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .listRowBackground(Theme.brand.opacity(0.07))
                .contextMenu { stationContextMenu(for: match) }
            } header: {
                sectionHeader("Station Code", icon: "magnifyingglass.circle.fill")
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

    // MARK: - Deep Linking

    private func handleDeepLink(_ link: DeepLink) {
        // Claim the auto-load slot immediately so the location onChange can't
        // race ahead and navigate to the nearest station while we resolve the
        // deep-link station asynchronously.
        hasPushedNearbyStation = true

        let crs: String
        switch link {
        case .departures(let c): crs = c
        case .arrivals(let c): crs = c
        case .station(let c): crs = c
        case .service(let c, _): crs = c
        case .filteredDepartures(let c, _, _): crs = c
        case .filteredArrivals(let c, _, _): crs = c
        }

        // Use viewModel.stations so we benefit from any already-loaded data,
        // falling back to the cache. If stations aren't available yet, wait for
        // them to load (up to ~3 s) before giving up.
        Task {
            var stations = viewModel.stations.isEmpty ? (StationCache.load() ?? []) : viewModel.stations
            if stations.isEmpty {
                for await updated in viewModel.$stations.values where !updated.isEmpty {
                    stations = updated
                    break
                }
            }
            guard let station = stations.first(where: { $0.crsCode == crs }) else { return }

            if horizontalSizeClass != .regular {
                navigationPath = NavigationPath()
            }

            // Brief pause so the navigation stack is ready after a cold launch.
            try? await Task.sleep(for: .milliseconds(150))

            switch link {
            case .departures:
                navigate(to: StationDestination(station: station, boardType: .departures))
            case .arrivals:
                navigate(to: StationDestination(station: station, boardType: .arrivals))
            case .station:
                stationInfoCrs = station.crsCode
            case .service(_, let serviceId):
                navigate(to: StationDestination(station: station, boardType: .departures, pendingServiceID: serviceId))
            case .filteredDepartures(_, let filterCrs, let filterType):
                let filterStation = stations.first(where: { $0.crsCode == filterCrs })
                navigate(to: StationDestination(station: station, boardType: .departures, filterStation: filterStation, filterType: filterType))
            case .filteredArrivals(_, let filterCrs, let filterType):
                let filterStation = stations.first(where: { $0.crsCode == filterCrs })
                navigate(to: StationDestination(station: station, boardType: .arrivals, filterStation: filterStation, filterType: filterType))
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
            navigate(to: StationDestination(station: station, boardType: .departures))
        } label: {
            Label("Show Departures", systemImage: "arrow.up.right")
        }

        Button {
            navigate(to: StationDestination(station: station, boardType: .arrivals))
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
        let itemID = SharedDefaults.boardID(crs: station.crsCode, boardType: boardType)
        if let svc = nextServiceStore.summaries[itemID]?.service {
            let scheduled = boardType == .departures ? svc.std : svc.sta
            let location = boardType == .departures ? svc.destination.first?.locationName : svc.origin.first?.locationName
            Section("Next: " + [scheduled, location].compactMap { $0 }.joined(separator: " · ")) {
                Button {
                    if horizontalSizeClass == .regular {
                        selectedStation = StationDestination(station: station, boardType: boardType)
                        selectedService = svc
                    } else {
                        nextServiceStore.sheetItem = NextServiceSheetItem(service: svc, boardType: boardType)
                    }
                } label: {
                    Label("View Service", systemImage: "train.side.front.car")
                }
            }
            Divider()
        }

        Button {
            navigate(to: StationDestination(station: station, boardType: .departures))
        } label: {
            Label("Show Departures", systemImage: "arrow.up.right")
        }

        Button {
            navigate(to: StationDestination(station: station, boardType: .arrivals))
        } label: {
            Label("Show Arrivals", systemImage: "arrow.down.left")
        }

        Divider()

        // Switch board type
        let otherType: BoardType = boardType == .departures ? .arrivals : .departures
        let otherID = SharedDefaults.boardID(crs: station.crsCode, boardType: otherType)
        let otherExists = favouriteBoardIDs.contains(otherID)
        if otherExists {
            Text("\(otherType.rawValue.capitalized) already favourited")
                .foregroundStyle(.secondary)
        } else {
            Button {
                var current = favouriteBoardIDs
                let oldID = SharedDefaults.boardID(crs: station.crsCode, boardType: boardType)
                if let idx = current.firstIndex(of: oldID) {
                    current[idx] = otherID
                }
                setFavouriteBoards(current)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label("Change to \(otherType.rawValue.capitalized)", systemImage: otherType == .departures ? "arrow.up.right" : "arrow.down.left")
            }
        }

        Button {
            removeFavouriteByID(SharedDefaults.boardID(crs: station.crsCode, boardType: boardType))
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
    private func filterContextMenu(for parsed: ParsedBoardID) -> some View {
        if let filterCrs = parsed.filterCrs, let filterType = parsed.filterType {
            let station = viewModel.stations.first(where: { $0.crsCode == parsed.crs })
            let filterStation = viewModel.stations.first(where: { $0.crsCode == filterCrs })
            let isFavourite = favouriteBoardIDs.contains(parsed.id)

            if let svc = nextServiceStore.summaries[parsed.id]?.service {
                let scheduled = parsed.boardType == .departures ? svc.std : svc.sta
                let location = parsed.boardType == .departures ? svc.destination.first?.locationName : svc.origin.first?.locationName
                Section("Next: " + [scheduled, location].compactMap { $0 }.joined(separator: " · ")) {
                    Button {
                        if horizontalSizeClass == .regular {
                            if let station, let filterStation {
                                selectedStation = StationDestination(station: station, boardType: parsed.boardType, filterStation: filterStation, filterType: filterType)
                            }
                            selectedService = svc
                        } else {
                            nextServiceStore.sheetItem = NextServiceSheetItem(service: svc, boardType: parsed.boardType)
                        }
                    } label: {
                        Label("View Service", systemImage: "train.side.front.car")
                    }
                }
                Divider()
            }

            Button {
                if let station, let filterStation {
                    navigate(to: StationDestination(station: station, boardType: parsed.boardType, filterStation: filterStation, filterType: filterType))
                }
            } label: {
                Label("Show Board", systemImage: "line.3.horizontal.decrease.circle")
            }

            Menu {
                Button {
                    if let station { navigate(to: StationDestination(station: station, boardType: .departures)) }
                } label: { Label("Departures", systemImage: "arrow.up.right") }
                Button {
                    if let station { navigate(to: StationDestination(station: station, boardType: .arrivals)) }
                } label: { Label("Arrivals", systemImage: "arrow.down.left") }
                Button { stationInfoCrs = parsed.crs } label: { Label("Station Info", systemImage: "info.circle") }
                if let station {
                    Button { openInMaps(station) } label: { Label("Open in Maps", systemImage: "map") }
                }
            } label: {
                Label(station?.name ?? parsed.crs, systemImage: "building.2")
            }

            Menu {
                Button {
                    if let filterStation { navigate(to: StationDestination(station: filterStation, boardType: .departures)) }
                } label: { Label("Departures", systemImage: "arrow.up.right") }
                Button {
                    if let filterStation { navigate(to: StationDestination(station: filterStation, boardType: .arrivals)) }
                } label: { Label("Arrivals", systemImage: "arrow.down.left") }
                Button { stationInfoCrs = filterCrs } label: { Label("Station Info", systemImage: "info.circle") }
                if let filterStation {
                    Button { openInMaps(filterStation) } label: { Label("Open in Maps", systemImage: "map") }
                }
            } label: {
                Label(filterStation?.name ?? filterCrs, systemImage: "building.2")
            }

            Divider()

            Button {
                if isFavourite {
                    removeFilterFromFavourites(id: parsed.id)
                } else {
                    addFilterToFavourites(id: parsed.id)
                }
            } label: {
                if isFavourite {
                    Label("Remove Favourite", systemImage: "star.slash")
                } else {
                    Label("Add to Favourites", systemImage: "star.fill")
                }
            }

            if !isFavourite {
                Button {
                    withAnimation { SharedDefaults.removeRecentFilter(id: parsed.id) }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
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

    private func filterCrsPill(fromCrs: String, toCrs: String) -> some View {
        VStack(spacing: 1) {
            Text(fromCrs)
                .font(Theme.crsFont)
                .foregroundStyle(Theme.brand)
            Image(systemName: "arrow.down")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.secondary)
            Text(toCrs)
                .font(Theme.crsFont)
                .foregroundStyle(Theme.brand)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Theme.brandSubtle, in: RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private func nearbyRow(_ station: Station) -> some View {
        NavigationLink(value: StationDestination(station: station, boardType: .departures)) {
            nearbyRowContent(station)
        }
        .contextMenu { stationContextMenu(for: station) }
    }

    private func nearbyRowContent(_ station: Station) -> some View {
        HStack {
            crsPill(station.crsCode)
            VStack(alignment: .leading) {
                Text(station.name).font(Font.headline.smallCapsIfEnabled(stationNamesSmallCaps))
            }
            Spacer()
            if hasAnyFavourite(station) {
                Image(systemName: "star.fill").foregroundStyle(Theme.brand).font(.caption)
            }
            if let distance = distanceInMiles(to: station) {
                Text(String(format: "%.1f mi", distance)).font(.caption).foregroundStyle(.tertiary)
            }
            if horizontalSizeClass == .regular {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func stationRow(_ station: Station) -> some View {
        NavigationLink(value: StationDestination(station: station, boardType: .departures)) {
            stationRowContent(station)
        }
        .contextMenu { stationContextMenu(for: station) }
    }

    private func stationRowContent(_ station: Station) -> some View {
        HStack {
            crsPill(station.crsCode)
            VStack(alignment: .leading) {
                Text(station.name).font(Font.headline.smallCapsIfEnabled(stationNamesSmallCaps))
            }
            Spacer()
            if hasAnyFavourite(station) {
                Image(systemName: "star.fill").foregroundStyle(Theme.brand).font(.caption)
            }
            if horizontalSizeClass == .regular {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func favouriteRowContent<Pill: View>(
        @ViewBuilder pill: () -> Pill,
        title: String,
        filterLabel: String?,
        boardType: BoardType,
        trailingIcon: String?,
        itemID: String,
        showNextService: Bool,
        onPillTap: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                pill()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Font.headline.smallCapsIfEnabled(stationNamesSmallCaps))
                    if let filterLabel {
                        Text(filterLabel)
                            .font(Font.subheadline.smallCapsIfEnabled(stationNamesSmallCaps))
                            .foregroundStyle(.secondary)
                    }
                    Text(boardType.rawValue.capitalized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if horizontalSizeClass == .regular {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            if showNextService {
                nextServicePill(id: itemID, boardType: boardType, onTap: onPillTap)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func favouriteStationRow(_ station: Station, boardType: BoardType, itemID: String) -> some View {
        NavigationLink(value: StationDestination(station: station, boardType: boardType)) {
            favouriteRowContent(
                pill: { crsPill(station.crsCode) },
                title: station.name,
                filterLabel: nil,
                boardType: boardType,
                trailingIcon: boardType == .departures ? "arrow.up.right" : "arrow.down.left",
                itemID: itemID,
                showNextService: showNextServiceOnFavourites,
                onPillTap: {
                    if let svc = nextServiceStore.summaries[itemID]?.service {
                        navigate(to: StationDestination(station: station, boardType: boardType, pendingServiceID: svc.serviceId))
                    }
                }
            )
        }
        .contextMenu { favouriteStationContextMenu(for: station, boardType: boardType) }
    }

    private func nextServiceState(id: String, boardType: BoardType) -> NextServicePillView.ContentState {
        guard let summary = nextServiceStore.summaries[id] else {
            return nextServiceStore.failedIDs.contains(id) ? .failed : .loading
        }
        guard let service = summary.service else { return .empty }
        return .service(service, boardType)
    }

    @ViewBuilder
    private func nextServicePill(id: String, boardType: BoardType, onTap: (() -> Void)? = nil) -> some View {
        let state = nextServiceState(id: id, boardType: boardType)
        let refreshID = nextServiceStore.refreshIDs[id, default: 0]
        if case .service = state, let onTap, nextServiceTappable {
            Button(action: onTap) {
                NextServicePillView(state: state, refreshID: refreshID)
            }
            .buttonStyle(.plain)
        } else {
            NextServicePillView(state: state, refreshID: refreshID)
        }
    }

    @ViewBuilder
    private func filterRow(_ parsed: ParsedBoardID, showStar: Bool = false) -> some View {
        if let filterCrs = parsed.filterCrs, let filterType = parsed.filterType {
            let station = viewModel.stations.first(where: { $0.crsCode == parsed.crs })
            let filterStation = viewModel.stations.first(where: { $0.crsCode == filterCrs })
            let fromCrs = filterType == "from" ? filterCrs : parsed.crs
            let toCrs   = filterType == "from" ? parsed.crs : filterCrs
            let stationName = station?.name ?? parsed.crs
            let filterLabel = filterType == "to"
                ? "Calling at \(filterStation?.name ?? filterCrs)"
                : "From \(filterStation?.name ?? filterCrs)"

            if let station, let filterStation {
                let dest = StationDestination(station: station, boardType: parsed.boardType, filterStation: filterStation, filterType: filterType)
                NavigationLink(value: dest) {
                    favouriteRowContent(
                        pill: { filterCrsPill(fromCrs: fromCrs, toCrs: toCrs) },
                        title: stationName,
                        filterLabel: filterLabel,
                        boardType: parsed.boardType,
                        trailingIcon: showStar ? "arrow.right.arrow.left" : nil,
                        itemID: parsed.id,
                        showNextService: showStar && showNextServiceOnFavourites,
                        onPillTap: {
                            if let svc = nextServiceStore.summaries[parsed.id]?.service {
                                navigate(to: StationDestination(station: station, boardType: parsed.boardType, pendingServiceID: svc.serviceId, filterStation: filterStation, filterType: filterType))
                            }
                        }
                    )
                }
                .contextMenu { filterContextMenu(for: parsed) }
            } else {
                Button {
                    if let station, let filterStation {
                        navigate(to: StationDestination(station: station, boardType: parsed.boardType, filterStation: filterStation, filterType: filterType))
                    }
                } label: {
                    favouriteRowContent(
                        pill: { filterCrsPill(fromCrs: fromCrs, toCrs: toCrs) },
                        title: stationName,
                        filterLabel: filterLabel,
                        boardType: parsed.boardType,
                        trailingIcon: showStar ? "arrow.right.arrow.left" : nil,
                        itemID: parsed.id,
                        showNextService: showStar && showNextServiceOnFavourites
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu { filterContextMenu(for: parsed) }
            }
        }
    }
}
