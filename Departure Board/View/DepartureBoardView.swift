//
//  DepartureBoardView.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import SwiftUI
import Combine
import UIKit

private struct BoardLoadState {
    var board: DepartureBoard? = nil
    var isLoading: Bool = true
    var errorMessage: String? = nil
    var lastUpdate: Date? = nil
    var showingStaleCache: Bool = false
}

private struct FilterState {
    var station: Station? = nil
    var type: String = "to"
    var showSheet: Bool = false
}

struct DepartureBoardView: View {

    let station: Station
    var initialBoardType: BoardType = .departures
    var pendingServiceID: String?
    var initialFilterStation: Station?
    var initialFilterType: String?
    @Binding var navigationPath: NavigationPath
    var selectedService: Binding<Service?>?
    var onNavigateToStation: ((StationDestination) -> Void)?

    // MARK: - State
    @State private var boardLoad = BoardLoadState()
    @State private var filter = FilterState()
    @State private var showInfo = false
    @State private var selectedBoard: BoardType = .departures
    @State private var loadTask: Task<Void, Never>?
    @State private var selectedServiceID: String?
    @State private var stationInfoCrs: String?
    @State private var didAutoNavigate = false
    @State private var timeOffset: Int? = nil
    @State private var showNrccMessages = false
    @State private var showSubscribe = false
    @State private var subscribeFeature: PaywallFeature = .all
    @State private var showReviewPrompt = false
    @State private var pendingFilterSheetNavigation: StationDestination?
    @AppStorage(SharedDefaults.Keys.favouriteBoards, store: SharedDefaults.shared) private var favouriteBoardsData: Data = Data()
    @AppStorage(SharedDefaults.Keys.rowTheme) private var rowThemeRaw: String = RowTheme.none.rawValue
    @AppStorage(SharedDefaults.Keys.colourVibrancy) private var colourVibrancyRaw: String = ColourVibrancy.vibrant.rawValue

    private var rowTheme: RowTheme { RowTheme(rawValue: rowThemeRaw) ?? .none }
    private var colourVibrancy: ColourVibrancy { ColourVibrancy(rawValue: colourVibrancyRaw) ?? .vibrant }
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.stationNamesSmallCaps) private var stationNamesSmallCaps
    @EnvironmentObject private var entitlement: EntitlementManager
    private let freeFavouriteLimit = 1

    private var effectiveRowTheme: RowTheme {
        entitlement.hasPremiumAccess ? rowTheme : .none
    }

    private var effectiveColourVibrancy: ColourVibrancy {
        entitlement.hasPremiumAccess ? colourVibrancy : .vibrant
    }

    init(station: Station, initialBoardType: BoardType = .departures, pendingServiceID: String? = nil, initialFilterStation: Station? = nil, initialFilterType: String? = nil, selectedService: Binding<Service?>? = nil, onNavigateToStation: ((StationDestination) -> Void)? = nil, navigationPath: Binding<NavigationPath>) {
        self.station = station
        self.initialBoardType = initialBoardType
        self.pendingServiceID = pendingServiceID
        self.initialFilterStation = initialFilterStation
        self.initialFilterType = initialFilterType
        self.selectedService = selectedService
        self.onNavigateToStation = onNavigateToStation
        self._navigationPath = navigationPath
        _selectedBoard = State(initialValue: initialBoardType)
        _filter = State(initialValue: FilterState(station: initialFilterStation, type: initialFilterType ?? "to"))
    }

    private var highlightedServiceID: String? {
        selectedService?.wrappedValue?.serviceId ?? selectedServiceID
    }

    private var hasTrains: Bool {
        !(boardLoad.board?.trainServices ?? []).isEmpty
    }

    private var hasBuses: Bool {
        !(boardLoad.board?.busServices ?? []).isEmpty
    }

    private var hasAnyServices: Bool {
        hasTrains || hasBuses
    }

    private var shareBoardURL: URL? {
        WebShareURL.boardURL(
            crs: station.crsCode,
            boardType: selectedBoard,
            filterCrs: filter.station?.crsCode,
            filterType: filter.type
        )
    }

    private func presentSubscribe(_ feature: PaywallFeature = .all) {
        subscribeFeature = feature
        showSubscribe = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func requirePremium(_ feature: PaywallFeature = .all) -> Bool {
        guard entitlement.hasPremiumAccess else {
            presentSubscribe(feature)
            return false
        }
        return true
    }

    var body: some View {
        Group {
            if let serviceBinding = selectedService {
                List(selection: serviceBinding) {
                    serviceListRows
                }
            } else {
                List {
                    serviceListRows
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(6)
        .refreshable {
            await loadBoard(type: selectedBoard)
        }
        .overlay {
            if boardLoad.isLoading && boardLoad.board == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background)
            }
        }
        .safeAreaInset(edge: .top) {
            let showTimeOffset = (timeOffset ?? 0) != 0
            let showFilter = filter.station != nil
            if showTimeOffset || showFilter {
                HStack(spacing: 8) {
                    if showTimeOffset {
                        Button {
                            timeOffset = nil
                            scheduleLoad()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text("From \(showingFromTime)")
                                    .font(.caption.weight(.semibold))
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if showFilter {
                        Button {
                            filter.station = nil
                            scheduleLoad()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.brand)
                                Text(filterChipLabel)
                                    .font(.caption.weight(.semibold))
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: timeOffset)
        .animation(.easeInOut(duration: 0.25), value: filter.station?.crsCode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if let shareBoardURL {
                        ShareLink(item: shareBoardURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    Button {
                        toggleBoardFavourite()
                    } label: {
                        Image(systemName: isBoardFavourited ? "star.fill" : "star")
                            .foregroundStyle(Theme.brand)
                    }
                    Button {
                        filter.showSheet = true
                    } label: {
                        Image(systemName: filter.station != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    Button {
                        guard requirePremium(.stationInfo) else { return }
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showInfo) {
            if entitlement.hasPremiumAccess {
                StationInfoView(crs: station.crsCode, onDismiss: {
                    showInfo = false
                }, onNavigate: { boardType in
                    showInfo = false
                    selectedBoard = boardType
                })
            } else {
                SubscribeView(initialFeature: .stationInfo)
            }
        }
        .sheet(item: $stationInfoCrs) { crs in
            if entitlement.hasPremiumAccess {
                StationInfoView(crs: crs, onDismiss: {
                    stationInfoCrs = nil
                }, onNavigate: { boardType in
                    if let station = StationCache.load()?.first(where: { $0.crsCode == crs }) {
                        stationInfoCrs = nil
                        let dest = StationDestination(station: station, boardType: boardType)
                        if let onNavigateToStation { onNavigateToStation(dest) } else { navigationPath.append(dest) }
                    }
                })
            } else {
                SubscribeView(initialFeature: .stationInfo)
            }
        }
        .sheet(isPresented: $filter.showSheet) {
            FilterStationSheet(
                currentStationCrs: station.crsCode,
                currentFilterStation: filter.station,
                filterType: $filter.type,
                onSelect: { selected in
                    filter.station = selected
                    filter.showSheet = false
                    SharedDefaults.addRecentFilter(id: SharedDefaults.boardID(crs: station.crsCode, boardType: selectedBoard, filterCrs: selected.crsCode, filterType: filter.type))
                    scheduleLoad(showLoading: true)
                },
                onReverse: {
                    guard let currentFilterStation = filter.station else { return }
                    pendingFilterSheetNavigation = StationDestination(
                        station: currentFilterStation,
                        boardType: selectedBoard,
                        filterStation: station,
                        filterType: filter.type
                    )
                    filter.showSheet = false
                }
            )
        }
        .safeAreaInset(edge: .bottom, alignment: .leading) {
            Picker("Board Type", selection: $selectedBoard) {
                ForEach(BoardType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .padding()
        }
        .navigationTitle(station.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showSubscribe) {
            SubscribeView(initialFeature: subscribeFeature)
        }
        .alert("Enjoying Departure Board?", isPresented: $showReviewPrompt) {
            Button("Yes") {
                ReviewPromptManager.shared.handlePositiveReviewResponse()
            }
            Button("Not really", role: .cancel) {
                ReviewPromptManager.shared.handleNegativeReviewResponse()
            }
        } message: {
            Text("Would you like to leave a quick App Store review?")
        }
        .navigationDestination(for: Service.self) { service in
            if entitlement.hasPremiumAccess {
                ServiceDetailView(
                    service: service,
                    boardType: selectedBoard,
                    navigationPath: $navigationPath
                )
                .onAppear {
                    selectedServiceID = service.serviceId
                }
                .onDisappear {
                    withAnimation(.easeOut(duration: 0.6)) {
                        selectedServiceID = nil
                    }
                }
            } else {
                SubscribeView(initialFeature: .serviceDetail)
            }
        }
        .onChange(of: selectedBoard) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            timeOffset = nil
            filter.station = nil
            scheduleLoad(showLoading: true)
        }
        .onChange(of: filter.showSheet) {
            guard !filter.showSheet, let destination = pendingFilterSheetNavigation else { return }
            pendingFilterSheetNavigation = nil
            if let onNavigateToStation {
                onNavigateToStation(destination)
            } else {
                navigationPath.append(destination)
            }
        }
        .task {
            await loadBoard(type: selectedBoard, showLoading: true)
            if let pendingServiceID, !didAutoNavigate,
               let service = (boardLoad.board?.trainServices ?? []).first(where: { $0.serviceId == pendingServiceID })
                    ?? (boardLoad.board?.busServices ?? []).first(where: { $0.serviceId == pendingServiceID }) {
                if entitlement.hasPremiumAccess {
                    didAutoNavigate = true
                    if let selectedService {
                        selectedService.wrappedValue = service
                    } else {
                        navigationPath.append(service)
                    }
                } else {
                    presentSubscribe(.serviceDetail)
                }
            }
            while !Task.isCancelled {
                let interval: Double = ProcessInfo.processInfo.isLowPowerModeEnabled ? 120 : 60
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                scheduleLoad(silent: true)
            }
        }
    }

    // MARK: - Service List Rows

    @ViewBuilder
    private var serviceListRows: some View {
        if hasAnyServices {
            // Show earlier trains button
            Section {
                Button {
                    guard requirePremium(.travelMode) else { return }
                    let current = timeOffset ?? 0
                    let newOffset = max(current - 30, -120)
                    timeOffset = newOffset
                    scheduleLoad(debounce: true)
                } label: {
                    HStack {
                        Spacer()
                        Label("Show earlier services", systemImage: "chevron.up")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .foregroundStyle(Theme.brand)
                }
                .listRowBackground(Theme.brandSubtle)
                .disabled((timeOffset ?? 0 <= -120) || !entitlement.hasPremiumAccess)
            }

            // NRCC messages
            if let messages = boardLoad.board?.nrccMessages, !messages.isEmpty {
                Section {
                    Button {
                        withAnimation { showNrccMessages.toggle() }
                    } label: {
                        HStack {
                            Label("\(messages.count == 1 ? "1 notice" : "\(messages.count) notices")", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: showNrccMessages ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    if showNrccMessages {
                        ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                            Text(message)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .listRowBackground(Color.orange.opacity(0.08))
            }

            // Train services
            if let trains = boardLoad.board?.trainServices, !trains.isEmpty {
                Section {} header: {
                    HStack(spacing: 6) {
                        Label("Trains", systemImage: "tram.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.brand)
                            .textCase(nil)
                        updatedLabel
                    }
                }

                ForEach(Array(trains.enumerated()), id: \.element.id) { index, service in
                    Section { serviceRow(service, index: index) }
                }
            }

            // Bus services — always show header; carries updated label when no trains
            if let buses = boardLoad.board?.busServices, !buses.isEmpty {
                Section {} header: {
                    HStack(spacing: 6) {
                        Label("Buses", systemImage: "bus.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.brand)
                            .textCase(nil)
                        if !hasTrains { updatedLabel }
                    }
                }

                ForEach(Array(buses.enumerated()), id: \.element.id) { index, service in
                    Section { serviceRow(service, index: index) }
                }
            }

            // Show later trains button
            Section {
                Button {
                    guard requirePremium(.travelMode) else { return }
                    let current = timeOffset ?? 0
                    timeOffset = current + 30
                    scheduleLoad(debounce: true)
                } label: {
                    HStack {
                        Spacer()
                        Label("Show later services", systemImage: "chevron.down")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .foregroundStyle(Theme.brand)
                }
                .listRowBackground(Theme.brandSubtle)
                .disabled(!entitlement.hasPremiumAccess)
            }

            HStack {
                Spacer()
                Image("NRE")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .opacity(0.6)
                Spacer()
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else if boardLoad.errorMessage != nil {
            VStack(spacing: 12) {
                Text(boardLoad.errorMessage ?? "")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    scheduleLoad(showLoading: true)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: .infinity)
        } else if !boardLoad.isLoading {
            if let filterStation = filter.station {
                VStack(spacing: 12) {
                    (Text("No services \(filter.type == "to" ? "calling at" : "from") ") + Text(filterStation.name).font(Font.body.smallCapsIfEnabled(stationNamesSmallCaps)))
                        .foregroundStyle(.secondary)
                    Button("Clear Filter") {
                        self.filter.station = nil
                        scheduleLoad()
                    }
                    .foregroundStyle(Theme.brand)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                Text("No services available")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Service Row

    @ViewBuilder
    private func serviceRow(_ service: Service, index: Int = 0) -> some View {
        let colours = OperatorColours.entry(for: service.operatorCode)
        let isHighlighted = highlightedServiceID == service.serviceId

        Group {
            if entitlement.hasPremiumAccess {
                NavigationLink(value: service) {
                    DepartureRow(service: service, boardType: selectedBoard, rowTheme: effectiveRowTheme, colourVibrancy: effectiveColourVibrancy, operatorColours: colours)
                }
            } else {
                Button {
                    presentSubscribe(.serviceDetail)
                } label: {
                    DepartureRow(service: service, boardType: selectedBoard, rowTheme: effectiveRowTheme, colourVibrancy: effectiveColourVibrancy, operatorColours: colours)
                }
                .buttonStyle(.plain)
            }
        }
        .contextMenu { serviceContextMenu(service) }
        .listRowBackground(rowBackground(theme: effectiveRowTheme, vibrancy: effectiveColourVibrancy, colours: colours, isHighlighted: isHighlighted))
    }

    @ViewBuilder
    private func rowBackground(theme: RowTheme, vibrancy: ColourVibrancy, colours: OperatorColours.Entry, isHighlighted: Bool) -> some View {
        if isHighlighted {
            Theme.brandSubtle
        } else {
            switch theme {
            case .none:
                Color(.secondarySystemGroupedBackground)
            case .trackline:
                TracklineBackground(colour: colours.primary, vibrancy: vibrancy)
            case .signalRail, .timeTile, .platformPulse:
                Color(.secondarySystemGroupedBackground)
            case .timePanel:
                TimePanelBackground(colour: colours.primary, vibrancy: vibrancy)
            case .boardWash:
                colours.primary.opacity(vibrancy.opacity)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func serviceContextMenu(_ service: Service) -> some View {
        // Info section (non-interactive)
        Section {
            Text("\(service.operator)")
            if let platform = service.platform {
                Text("Platform \(platform)")
            }
            Text("Scheduled: \(service.scheduled)")
            if service.estimated.lowercased() != "on time" {
                Text("Expected: \(service.estimated)")
            }
        }

        // Origin station actions
        if let origin = service.origin.first {
            Section(origin.locationName) {
                stationMenuButtons(crs: origin.crs, name: origin.locationName)
            }
        }

        // Destination station actions
        if let destination = service.destination.first {
            Section(destination.locationName) {
                stationMenuButtons(crs: destination.crs, name: destination.locationName)

                if destination.crs != station.crsCode,
                   let destStation = StationCache.load()?.first(where: { $0.crsCode == destination.crs }) {
                    Button {
                        filter.station = destStation
                        filter.type = "to"
                        SharedDefaults.addRecentFilter(id: SharedDefaults.boardID(crs: station.crsCode, boardType: selectedBoard, filterCrs: destination.crs, filterType: "to"))
                        scheduleLoad(showLoading: true)
                    } label: {
                        Label("Filter to \(destination.locationName)", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func stationMenuButtons(crs: String, name: String) -> some View {
        if let station = StationCache.load()?.first(where: { $0.crsCode == crs }) {
            Button {
                let dest = StationDestination(station: station, boardType: .departures)
                if let onNavigateToStation { onNavigateToStation(dest) } else { navigationPath.append(dest) }
            } label: {
                Label("Departures", systemImage: "arrow.up.right")
            }

            Button {
                let dest = StationDestination(station: station, boardType: .arrivals)
                if let onNavigateToStation { onNavigateToStation(dest) } else { navigationPath.append(dest) }
            } label: {
                Label("Arrivals", systemImage: "arrow.down.left")
            }
        }

        Button {
            guard requirePremium(.stationInfo) else { return }
            stationInfoCrs = crs
        } label: {
            Label("Station Information", systemImage: "info.circle")
        }
    }

    // MARK: - Favourites

    private var favouriteBoardIDs: [String] {
        (try? JSONDecoder().decode([String].self, from: favouriteBoardsData)) ?? []
    }

    private var currentFavouriteID: String {
        if let fs = filter.station {
            return SharedDefaults.boardID(crs: station.crsCode, boardType: selectedBoard, filterCrs: fs.crsCode, filterType: filter.type)
        }
        return SharedDefaults.boardID(crs: station.crsCode, boardType: selectedBoard)
    }

    private var isBoardFavourited: Bool {
        favouriteBoardIDs.contains(currentFavouriteID)
    }

    private func toggleBoardFavourite() {
        var items = favouriteBoardIDs
        let id = currentFavouriteID

        if let idx = items.firstIndex(of: id) {
            items.remove(at: idx)
        } else {
            if !entitlement.hasPremiumAccess && items.count >= freeFavouriteLimit {
                presentSubscribe(.favourites)
                return
            }
            items.append(id)
            if filter.station != nil {
                SharedDefaults.removeRecentFilter(id: id)
            }
        }

        favouriteBoardsData = (try? JSONEncoder().encode(items)) ?? Data()
        let allCodes = Set((StationCache.load() ?? []).map(\.crsCode))
        SharedDefaults.syncStationFavourites(from: items, allStationCodes: allCodes)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Helper Methods

    @ViewBuilder
    private var updatedLabel: some View {
        if let updated = boardLoad.lastUpdate {
            HStack(spacing: 6) {
                TimelineView(.periodic(from: updated, by: 10)) { ctx in
                    Text(ContentView.fuzzyLabel(from: updated, tick: ctx.date))
                        .font(.caption2)
                }
                if boardLoad.showingStaleCache {
                    Text("Cached • couldn't refresh")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            .foregroundStyle(boardLoad.showingStaleCache ? AnyShapeStyle(.red) : AnyShapeStyle(Color(.secondaryLabel).opacity(0.65)))
            .textCase(nil)
        }
    }

    private var filterChipLabel: String {
        let name = boardLoad.board?.filterLocationName ?? filter.station?.name ?? ""
        return filter.type == "to" ? "Calling at \(name)" : "From \(name)"
    }

    private var showingFromTime: String {
        let offsetDate = Date().addingTimeInterval(Double(timeOffset ?? 0) * 60)
        let offsetString = offsetDate.formatted(date: .omitted, time: .shortened)

        // If the first train is earlier than our calculated offset, use the train's time
        if let firstScheduled = boardLoad.board?.trainServices?.first?.scheduled,
           firstScheduled < offsetString {
            return firstScheduled
        }
        return offsetString
    }

    private static let boardErrorMessages = [
        "This service has been delayed — by a network error.",
        "We're sorry for the inconvenience. Live data has failed to arrive.",
        "The 12:00 to your screen has been cancelled due to a network fault.",
        "Signal failure. Live departures couldn't get through.",
        "Leaves on the line. Or possibly a network error.",
        "This train is currently being held at a red light.",
    ]

    /// Cancel any in-flight load and start a new one. Pass `debounce` for rapid-fire
    /// triggers (e.g. time offset buttons) so we don't fire on every tap.
    private func scheduleLoad(showLoading: Bool = false, silent: Bool = false, debounce: Bool = false) {
        loadTask?.cancel()
        loadTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
            }
            await loadBoard(type: selectedBoard, showLoading: showLoading, silent: silent)
        }
    }

    private func loadBoard(type: BoardType, showLoading: Bool = false, silent: Bool = false) async {
        let cacheKey = BoardCacheKey(
            crs: station.crsCode,
            boardType: type,
            filterCrs: filter.station?.crsCode,
            filterType: filter.station == nil ? nil : filter.type
        )

        if showLoading { boardLoad.isLoading = true }

        if let cached = BoardCacheStore.shared.load(for: cacheKey) {
            withAnimation(.easeInOut(duration: 0.2)) {
                boardLoad.board = cached.board
                boardLoad.errorMessage = nil
            }
            boardLoad.lastUpdate = cached.loadedAt
            boardLoad.showingStaleCache = false
        }

        do {
            let result = try await StationViewModel.fetchBoard(for: station.crsCode, type: type, filterCrs: filter.station?.crsCode, filterType: filter.station != nil ? filter.type : nil, timeOffset: timeOffset)
            withAnimation(.easeInOut(duration: 0.3)) {
                boardLoad.board = result
                boardLoad.errorMessage = nil
            }
            if !silent { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            boardLoad.lastUpdate = Date()
            boardLoad.showingStaleCache = false
            BoardCacheStore.shared.save(board: result, for: cacheKey, loadedAt: boardLoad.lastUpdate ?? Date())

            let route = BoardRoute(
                crs: station.crsCode,
                boardType: type,
                filterCrs: filter.station?.crsCode,
                filterType: filter.station == nil ? nil : filter.type
            )
            RoutineEngine.shared.logBoardOpen(route: route)
            ActivityDonor.shared.donateBoardOpen(
                route: route,
                stationName: station.name,
                filterName: filter.station?.name,
                isFavourite: isBoardFavourited
            )

            if ReviewPromptManager.shared.recordGoodExperience() {
                showReviewPrompt = true
            }
        } catch {
            if boardLoad.board == nil {
                if !silent { boardLoad.errorMessage = DepartureBoardView.boardErrorMessages.randomElement()! }
                if !silent { UINotificationFeedbackGenerator().notificationOccurred(.error) }
                boardLoad.showingStaleCache = false
            } else {
                boardLoad.showingStaleCache = true
            }
            if !silent {
                ReviewPromptManager.shared.recordBadExperience()
            }
        }
        boardLoad.isLoading = false
    }
}

// MARK: - Departure Row Subview

struct DepartureRow: View {
    @Environment(\.stationNamesSmallCaps) private var stationNamesSmallCaps

    let service: Service
    let boardType: BoardType
    var rowTheme: RowTheme = .none
    var colourVibrancy: ColourVibrancy = .vibrant
    var operatorColours: OperatorColours.Entry = OperatorColours.entry(for: "ZZ")
    @Environment(\.colorScheme) private var colorScheme

    /// Black or white — whichever contrasts against the operator's primary colour.
    private var contrastColour: Color {
        operatorColours.primaryIsLight ? Color.black : Color.white
    }

    /// True when the time text sits on a solid coloured background (timeTile, timePanel, boardWash — vibrant only).
    private var timeIsOnColour: Bool {
        colourVibrancy == .vibrant && (rowTheme == .timeTile || rowTheme == .timePanel || rowTheme == .boardWash)
    }

    /// True when the whole row background is solid operator colour (boardWash vibrant only).
    private var rowIsOnColour: Bool {
        rowTheme == .boardWash && colourVibrancy == .vibrant
    }

    private var onPrimaryTextColour: Color {
        timeIsOnColour ? contrastColour : Color(.label)
    }

    private var stationNameColour: Color {
        rowIsOnColour ? contrastColour : Color(.label)
    }

    private var locations: [Location] {
        if boardType == .arrivals {
            return service.origin
        }
        return service.destination
    }

    private var isCancelled: Bool {
        service.isCancelled
    }

    private var isDelayed: Bool {
        let text = service.estimated.lowercased()
        return text.contains("delayed") || (isTimeFormat(service.estimated) && service.estimated > service.scheduled)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Time text — with optional tile background
            let timeView = Text(service.scheduled)
                .font(Theme.timeFont)
                .lineLimit(1)
                .fixedSize()
                .frame(width: 44, alignment: .leading)
                .foregroundStyle(onPrimaryTextColour)

            if rowTheme == .timeTile {
                timeView
                    .padding(.vertical, 2)
                    .padding(.horizontal, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(operatorColours.primary.opacity(colourVibrancy.opacity))
                    )
            } else {
                timeView
            }

            // Signal Rail divider between time and content
            if rowTheme == .signalRail {
                Rectangle()
                    .fill(operatorColours.primary.opacity(colourVibrancy.opacity))
                    .frame(width: 1.5)
                    .padding(.vertical, -4)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(locations.map(\.locationName).joined(separator: " & "))
                        .font(Font.title3.weight(.semibold).smallCapsIfEnabled(stationNamesSmallCaps))
                        .foregroundStyle(stationNameColour)

                    if isCancelled {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(adaptedStatusColor(.red))
                            .font(.caption)
                    } else if isDelayed {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(adaptedStatusColor(.orange))
                            .font(.caption)
                    }
                }

                let uniqueVias = Array(Set(locations.compactMap(\.via)))
                ForEach(uniqueVias, id: \.self) { via in
                    Text(via)
                        .font(Font.subheadline.smallCapsIfEnabled(stationNamesSmallCaps))
                        .foregroundStyle(stationNameColour.opacity(0.75))
                }

                if service.estimated.lowercased() != "on time" {
                    Text(isTimeFormat(service.estimated) ? "Expected at \(service.estimated)" : service.estimated)
                        .font(.subheadline)
                        .foregroundStyle(statusColor(for: service.estimated))
                }
            }

            Spacer()

            if rowTheme == .platformPulse, service.platform == nil {
                // No platform allocated yet — larger dot so it's clearly intentional
                Circle()
                    .fill(operatorColours.primary.opacity(colourVibrancy.opacity))
                    .frame(width: 14, height: 14)
            } else if let platform = service.platform {
                let isPulse = rowTheme == .platformPulse
                let badgeBg: Color = rowIsOnColour
                    ? contrastColour.opacity(0.25)
                    : isPulse
                        ? operatorColours.primary.opacity(colourVibrancy.opacity)
                        : (colorScheme == .dark ? Theme.platformBadgeDark : Theme.platformBadge)
                // Text colour must always be legible against its specific badge background.
                // — boardWash vibrant row: badge bg is semi-transparent contrast, text = contrast
                // — platformPulse vibrant: bg is full primary → WCAG black/white
                // — platformPulse tinted: bg is 22% primary over cell bg (light in light mode,
                //   dark in dark mode) → Color(.label) adapts automatically
                // — default badge: Theme colours are already paired correctly with dark/light text
                let badgeFg: Color = rowIsOnColour
                    ? contrastColour
                    : isPulse
                        ? (colourVibrancy == .vibrant ? contrastColour : Color(.label))
                        : (colorScheme == .dark ? Color.black : Color.white)
                Text(platform.uppercased() == "BUS" ? platform : "Plat \(platform)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(badgeFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeBg, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.vertical, Theme.rowPadding)
    }

    private func isTimeFormat(_ text: String) -> Bool {
        text.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil
    }

    private func statusColor(for etd: String) -> Color {
        let text = etd.lowercased()
        if text.contains("cancel") { return adaptedStatusColor(.red) }
        if text.contains("delayed") { return adaptedStatusColor(.red) }
        if text.contains("on time") { return Color(.label) }
        return adaptedStatusColor(.orange)
    }

    /// On a coloured background the raw status colour may be unreadable.
    /// On a dark primary → brighten toward white. On a light primary → darken toward black.
    /// On no special background → return as-is.
    private func adaptedStatusColor(_ base: Color) -> Color {
        guard rowIsOnColour else { return base }
        return operatorColours.primaryIsLight
            ? base.mix(with: .black, by: 0.35)
            : base.mix(with: .white, by: 0.45)
    }
}
