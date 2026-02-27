//
//  DepartureBoardView.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import SwiftUI
import Combine

struct DepartureBoardView: View {

    let station: Station
    var initialBoardType: BoardType = .departures
    var pendingServiceID: String?
    var initialFilterStation: Station?
    var initialFilterType: String?
    @Binding var navigationPath: NavigationPath

    // MARK: - State
    @State private var board: DepartureBoard?
    @State private var isLoading = true
    @State private var showInfo = false
    @State private var errorMessage: String?
    @State private var selectedBoard: BoardType = .departures
    @State private var selectedServiceID: String?
    @State private var stationInfoCrs: String?
    @State private var didAutoNavigate = false
    @State private var timeOffset: Int? = nil
    @State private var filterStation: Station? = nil
    @State private var filterType: String = "to"
    @State private var showFilterSheet = false
    @State private var lastBoardUpdate: Date? = nil
    @State private var tickDate = Date()
    @AppStorage(SharedDefaults.Keys.favouriteItems, store: SharedDefaults.shared) private var favouriteItemsData: Data = Data()
    @AppStorage(SharedDefaults.Keys.savedFilters, store: SharedDefaults.shared) private var savedFiltersData: Data = Data()

    init(station: Station, initialBoardType: BoardType = .departures, pendingServiceID: String? = nil, initialFilterStation: Station? = nil, initialFilterType: String? = nil, navigationPath: Binding<NavigationPath>) {
        self.station = station
        self.initialBoardType = initialBoardType
        self.pendingServiceID = pendingServiceID
        self.initialFilterStation = initialFilterStation
        self.initialFilterType = initialFilterType
        self._navigationPath = navigationPath
        _selectedBoard = State(initialValue: initialBoardType)
        _filterStation = State(initialValue: initialFilterStation)
        _filterType = State(initialValue: initialFilterType ?? "to")
    }

    private var hasTrains: Bool {
        !(board?.trainServices ?? []).isEmpty
    }

    private var hasBuses: Bool {
        !(board?.busServices ?? []).isEmpty
    }

    private var hasAnyServices: Bool {
        hasTrains || hasBuses
    }

    private var showServiceTypeHeaders: Bool {
        hasTrains && hasBuses
    }

    var body: some View {
        List {
            if hasAnyServices {
                // Show earlier trains button
                Section {
                    Button {
                        let current = timeOffset ?? 0
                        let newOffset = max(current - 30, -120)
                        timeOffset = newOffset
                        Task { await loadBoard(type: selectedBoard) }
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
                    .disabled(timeOffset ?? 0 <= -120)
                }

                // Train services
                if let trains = board?.trainServices, !trains.isEmpty {
                    if showServiceTypeHeaders {
                        Section {
                            Label("Trains", systemImage: "tram.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.brand)
                                .listRowBackground(Color.clear)
                        }
                    }

                    ForEach(trains) { service in
                        Section {
                            NavigationLink(value: service) {
                                DepartureRow(service: service, boardType: selectedBoard)
                            }
                            .contextMenu {
                                serviceContextMenu(service)
                            }
                            .listRowBackground(
                                selectedServiceID == service.serviceId
                                    ? Theme.brandSubtle : nil
                            )
                        }
                    }
                }

                // Bus services
                if let buses = board?.busServices, !buses.isEmpty {
                    if showServiceTypeHeaders {
                        Section {
                            Label("Buses", systemImage: "bus.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.brand)
                                .listRowBackground(Color.clear)
                        }
                    }

                    ForEach(buses) { service in
                        Section {
                            NavigationLink(value: service) {
                                DepartureRow(service: service, boardType: selectedBoard)
                            }
                            .contextMenu {
                                serviceContextMenu(service)
                            }
                            .listRowBackground(
                                selectedServiceID == service.serviceId
                                    ? Theme.brandSubtle : nil
                            )
                        }
                    }
                }

                // Show later trains button
                Section {
                    Button {
                        let current = timeOffset ?? 0
                        timeOffset = current + 30
                        Task { await loadBoard(type: selectedBoard) }
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
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else if !isLoading {
                if let filterStation {
                    VStack(spacing: 12) {
                        Text("No services \(filterType == "to" ? "calling at" : "from") \(filterStation.name)")
                            .foregroundStyle(.secondary)
                        Button("Clear Filter") {
                            self.filterStation = nil
                            Task { await loadBoard(type: selectedBoard) }
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
        .listStyle(.insetGrouped)
        .listSectionSpacing(6)
        .refreshable {
            await loadBoard(type: selectedBoard)
        }
        .overlay {
            if isLoading && board == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background)
            }
        }
        .safeAreaInset(edge: .top) {
            let showTimeOffset = (timeOffset ?? 0) != 0
            let showFilter = filterStation != nil
            if showTimeOffset || showFilter {
                HStack(spacing: 8) {
                    if showTimeOffset {
                        Button {
                            timeOffset = nil
                            Task { await loadBoard(type: selectedBoard) }
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
                            filterStation = nil
                            Task { await loadBoard(type: selectedBoard) }
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
        .animation(.easeInOut(duration: 0.25), value: filterStation?.crsCode)
        .onReceive(Timer.publish(every: 10, on: .main, in: .common).autoconnect()) { _ in
            tickDate = Date()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if let updated = lastBoardUpdate {
                        Text(ContentView.fuzzyLabel(from: updated, tick: tickDate))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Divider()
                            .frame(height: 16)
                    }
                    Button {
                        toggleBoardFavourite()
                    } label: {
                        Image(systemName: isBoardFavourited ? "star.fill" : "star")
                            .foregroundStyle(Theme.brand)
                    }
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: filterStation != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showInfo) {
            StationInfoView(crs: station.crsCode, onDismiss: {
                showInfo = false
            }, onNavigate: { boardType in
                showInfo = false
                selectedBoard = boardType
            })
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
        .sheet(isPresented: $showFilterSheet) {
            FilterStationSheet(
                currentStationCrs: station.crsCode,
                filterType: $filterType,
                onSelect: { selected in
                    filterStation = selected
                    showFilterSheet = false
                    SavedFilter.addRecent(stationCrs: station.crsCode, stationName: station.name, filterCrs: selected.crsCode, filterName: selected.name, filterType: filterType, boardType: selectedBoard)
                    Task { await loadBoard(type: selectedBoard) }
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
        .navigationDestination(for: Service.self) { service in
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
        }
        .onChange(of: selectedBoard) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            timeOffset = nil
            filterStation = nil
            Task {
                await loadBoard(type: selectedBoard, showLoading: true)
            }
        }
        .task {
            await loadBoard(type: selectedBoard, showLoading: true)
            if let pendingServiceID, !didAutoNavigate,
               let service = (board?.trainServices ?? []).first(where: { $0.serviceId == pendingServiceID })
                    ?? (board?.busServices ?? []).first(where: { $0.serviceId == pendingServiceID }) {
                didAutoNavigate = true
                navigationPath.append(service)
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                try? await loadBoard(type: selectedBoard, silent: true)
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
                        filterStation = destStation
                        filterType = "to"
                        SavedFilter.addRecent(stationCrs: station.crsCode, stationName: station.name, filterCrs: destination.crs, filterName: destination.locationName, filterType: "to", boardType: selectedBoard)
                        Task { await loadBoard(type: selectedBoard) }
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
                navigationPath.append(StationDestination(station: station, boardType: .departures))
            } label: {
                Label("Departures", systemImage: "arrow.up.right")
            }

            Button {
                navigationPath.append(StationDestination(station: station, boardType: .arrivals))
            } label: {
                Label("Arrivals", systemImage: "arrow.down.left")
            }
        }

        Button {
            stationInfoCrs = crs
        } label: {
            Label("Station Information", systemImage: "info.circle")
        }
    }

    // MARK: - Favourites

    private var favouriteItemIDs: [String] {
        (try? JSONDecoder().decode([String].self, from: favouriteItemsData)) ?? []
    }

    private var currentFavouriteID: String {
        if let fs = filterStation {
            return "\(station.crsCode)-\(selectedBoard.rawValue)-\(filterType)-\(fs.crsCode)"
        }
        return SharedDefaults.stationFavID(crs: station.crsCode, boardType: selectedBoard)
    }

    private var isBoardFavourited: Bool {
        favouriteItemIDs.contains(currentFavouriteID)
    }

    private func toggleBoardFavourite() {
        var items = favouriteItemIDs

        if let fs = filterStation {
            // Toggle filter favourite
            let filterID = currentFavouriteID
            var allFilters = (try? JSONDecoder().decode([SavedFilter].self, from: savedFiltersData)) ?? []

            if let idx = allFilters.firstIndex(where: { $0.id == filterID }) {
                let wasFav = allFilters[idx].isFavourite
                allFilters[idx].isFavourite = !wasFav
                if wasFav {
                    items.removeAll { $0 == filterID }
                } else {
                    items.append(filterID)
                }
            } else {
                // Filter doesn't exist yet — create and favourite it
                let newFilter = SavedFilter(stationCrs: station.crsCode, stationName: station.name, filterCrs: fs.crsCode, filterName: fs.name, filterType: filterType, boardType: selectedBoard, isFavourite: true)
                allFilters.append(newFilter)
                items.append(filterID)
            }

            if let data = try? JSONEncoder().encode(allFilters) {
                savedFiltersData = data
            }
        } else {
            // Toggle station favourite
            let id = currentFavouriteID
            if let idx = items.firstIndex(of: id) {
                items.remove(at: idx)
            } else {
                items.append(id)
            }
        }

        favouriteItemsData = (try? JSONEncoder().encode(items)) ?? Data()
        let allCodes = Set((StationCache.load() ?? []).map(\.crsCode))
        SharedDefaults.syncStationFavourites(from: items, allStationCodes: allCodes)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Helper Methods

    private var filterChipLabel: String {
        let name = board?.filterLocationName ?? filterStation?.name ?? ""
        return filterType == "to" ? "Calling at \(name)" : "From \(name)"
    }

    private var showingFromTime: String {
        let offsetDate = Date().addingTimeInterval(Double(timeOffset ?? 0) * 60)
        let offsetString = offsetDate.formatted(date: .omitted, time: .shortened)

        // If the first train is earlier than our calculated offset, use the train's time
        if let firstScheduled = board?.trainServices?.first?.scheduled,
           firstScheduled < offsetString {
            return firstScheduled
        }
        return offsetString
    }

    private func loadBoard(type: BoardType, showLoading: Bool = false, silent: Bool = false) async {
        if showLoading { isLoading = true }
        do {
            let result = try await StationViewModel.fetchBoard(for: station.crsCode, type: type, filterCrs: filterStation?.crsCode, filterType: filterStation != nil ? filterType : nil, timeOffset: timeOffset)
            withAnimation(.easeInOut(duration: 0.3)) {
                board = result
                errorMessage = nil
            }
            if !silent { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            lastBoardUpdate = Date()
        } catch {
            if !silent { errorMessage = "Failed to load board" }
            if !silent { UINotificationFeedbackGenerator().notificationOccurred(.error) }
        }
        isLoading = false
    }
}

// MARK: - Departure Row Subview

struct DepartureRow: View {

    let service: Service
    let boardType: BoardType
    @Environment(\.colorScheme) private var colorScheme

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
        HStack(alignment: .top, spacing: 12) {
            Text(service.scheduled)
                .font(Theme.timeFont)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(locations.map(\.locationName).joined(separator: " & "))
                        .font(.title3.weight(.semibold))

                    if isCancelled {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    } else if isDelayed {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                let uniqueVias = Array(Set(locations.compactMap(\.via)))
                ForEach(uniqueVias, id: \.self) { via in
                    Text(via)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if service.estimated.lowercased() != "on time" {
                    Text(isTimeFormat(service.estimated) ? "Expected at \(service.estimated)" : service.estimated)
                        .font(.subheadline)
                        .foregroundStyle(statusColor(for: service.estimated))
                }
            }

            Spacer()

            if let platform = service.platform {
                Text(platform.uppercased() == "BUS" ? platform : "Plat \(platform)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        colorScheme == .dark ? Theme.platformBadgeDark : Theme.platformBadge,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
            }
        }
        .padding(.vertical, Theme.rowPadding)
    }

    private func isTimeFormat(_ text: String) -> Bool {
        text.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil
    }

    private func statusColor(for etd: String) -> Color {
        let text = etd.lowercased()
        if text.contains("cancel") { return .red }
        if text.contains("delayed") { return .red }
        if text.contains("on time") { return .primary }
        return .orange
    }
}
