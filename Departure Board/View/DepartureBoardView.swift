//
//  DepartureBoardView.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import SwiftUI

private struct BoardLoadState {
    var board: DepartureBoard? = nil
    var isLoading: Bool = true
    var errorMessage: String? = nil
    var lastUpdate: Date? = nil
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
    @State private var selectedServiceID: String?
    @State private var stationInfoCrs: String?
    @State private var didAutoNavigate = false
    @State private var timeOffset: Int? = nil
    @State private var showNrccMessages = false
@AppStorage(SharedDefaults.Keys.favouriteBoards, store: SharedDefaults.shared) private var favouriteBoardsData: Data = Data()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.stationNamesSmallCaps) private var stationNamesSmallCaps

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

    private var showServiceTypeHeaders: Bool {
        hasTrains && hasBuses
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
                            filter.station = nil
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
        .animation(.easeInOut(duration: 0.25), value: filter.station?.crsCode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
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
                    let dest = StationDestination(station: station, boardType: boardType)
                    if let onNavigateToStation { onNavigateToStation(dest) } else { navigationPath.append(dest) }
                }
            })
        }
        .sheet(isPresented: $filter.showSheet) {
            FilterStationSheet(
                currentStationCrs: station.crsCode,
                filterType: $filter.type,
                onSelect: { selected in
                    filter.station = selected
                    filter.showSheet = false
                    SharedDefaults.addRecentFilter(id: SharedDefaults.boardID(crs: station.crsCode, boardType: selectedBoard, filterCrs: selected.crsCode, filterType: filter.type))
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
            filter.station = nil
            Task {
                await loadBoard(type: selectedBoard, showLoading: true)
            }
        }
        .task {
            await loadBoard(type: selectedBoard, showLoading: true)
            if let pendingServiceID, !didAutoNavigate,
               let service = (boardLoad.board?.trainServices ?? []).first(where: { $0.serviceId == pendingServiceID })
                    ?? (boardLoad.board?.busServices ?? []).first(where: { $0.serviceId == pendingServiceID }) {
                didAutoNavigate = true
                if let selectedService {
                    selectedService.wrappedValue = service
                } else {
                    navigationPath.append(service)
                }
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                try? await loadBoard(type: selectedBoard, silent: true)
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
                if showServiceTypeHeaders {
                    Section {
                        Label("Trains", systemImage: "tram.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.brand)
                            .listRowBackground(Color.clear)
                    }
                }

                ForEach(trains) { service in
                    Section { serviceRow(service) }
                }
            }

            // Bus services
            if let buses = boardLoad.board?.busServices, !buses.isEmpty {
                if showServiceTypeHeaders {
                    Section {
                        Label("Buses", systemImage: "bus.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.brand)
                            .listRowBackground(Color.clear)
                    }
                }

                ForEach(buses) { service in
                    Section { serviceRow(service) }
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
        } else if let errorMessage = boardLoad.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
        } else if !boardLoad.isLoading {
            if let filterStation = filter.station {
                VStack(spacing: 12) {
                    (Text("No services \(filter.type == "to" ? "calling at" : "from") ") + Text(filterStation.name).font(Font.body.smallCapsIfEnabled(stationNamesSmallCaps)))
                        .foregroundStyle(.secondary)
                    Button("Clear Filter") {
                        self.filter.station = nil
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

    // MARK: - Service Row

    @ViewBuilder
    private func serviceRow(_ service: Service) -> some View {
        NavigationLink(value: service) {
            DepartureRow(service: service, boardType: selectedBoard)
        }
        .contextMenu { serviceContextMenu(service) }
        .listRowBackground(highlightedServiceID == service.serviceId ? Theme.brandSubtle : nil)
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

    private func loadBoard(type: BoardType, showLoading: Bool = false, silent: Bool = false) async {
        if showLoading { boardLoad.isLoading = true }
        do {
            let result = try await StationViewModel.fetchBoard(for: station.crsCode, type: type, filterCrs: filter.station?.crsCode, filterType: filter.station != nil ? filter.type : nil, timeOffset: timeOffset)
            withAnimation(.easeInOut(duration: 0.3)) {
                boardLoad.board = result
                boardLoad.errorMessage = nil
            }
            if !silent { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            boardLoad.lastUpdate = Date()
        } catch {
            if !silent { boardLoad.errorMessage = "Failed to load board" }
            if !silent { UINotificationFeedbackGenerator().notificationOccurred(.error) }
        }
        boardLoad.isLoading = false
    }
}

// MARK: - Departure Row Subview

struct DepartureRow: View {
    @Environment(\.stationNamesSmallCaps) private var stationNamesSmallCaps

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
                .lineLimit(1)
                .fixedSize()
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(locations.map(\.locationName).joined(separator: " & "))
                        .font(Font.title3.weight(.semibold).smallCapsIfEnabled(stationNamesSmallCaps))

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
                        .font(Font.subheadline.smallCapsIfEnabled(stationNamesSmallCaps))
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
