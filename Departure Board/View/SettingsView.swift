//
//  SettingsView.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    @ObservedObject var viewModel: StationViewModel
    @AppStorage("nearbyStationCount") var nearbyCount: Int = 5
    @AppStorage("recentFilterCount") var recentFilterCount: Int = 3
    @AppStorage("showRecentFilters") var showRecentFilters: Bool = true
    @AppStorage("mapsProvider") var mapsProvider: String = "apple"
    @AppStorage("showNextServiceOnFavourites") var showNextServiceOnFavourites: Bool = true
    @AppStorage("nextServiceTappable") var nextServiceTappable: Bool = false
    @AppStorage("splitFlapRefresh") var splitFlapRefresh: Bool = false
    @AppStorage("stationNamesSmallCaps") var stationNamesSmallCaps: Bool = false
    @AppStorage(SharedDefaults.Keys.operatorColourStyle) var operatorColourStyleRaw: String = OperatorColourStyle.none.rawValue
    @AppStorage("autoLoadMode") var autoLoadMode: String = "off"
    @AppStorage("autoLoadDistanceMiles") var autoLoadDistanceMiles: Int = 2
    @AppStorage(SharedDefaults.Keys.favouriteBoards, store: SharedDefaults.shared) private var favouriteBoardsData: Data = Data()
    @State private var isRefreshing = false
    @State private var debugTapCount = 0
    @State private var debugTapResetTask: Task<Void, Never>? = nil
    @State private var showDebug = false
    @State private var lastRefresh: Date? = StationCache.lastRefreshDate()
    @State private var liveServiceExample: LiveServiceExample? = nil
    @State private var exportDocument = FavouritesDocument(data: Data())
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var importResult: ImportResult? = nil

    private struct ImportResult {
        let message: String
        let imported: [String]                      // human-readable label of each added board
        let skipped: [String]                       // human-readable label of each already-present board
        let rejected: [(id: String, reason: String)] // raw ID + explicit rejection reason
    }

    private var autoLoadModeDescription: String {
        switch autoLoadMode {
        case "off":
            return "The app opens on the station list. Nothing is loaded automatically."
        case "nearest":
            return "The nearest station's departure board is opened automatically."
        case "favourite":
            return "If a favourite board is within \(autoLoadDistanceMiles) mi, it opens automatically. Otherwise the station list is shown."
        case "favouriteOrNearest":
            return "Opens the nearest favourite within \(autoLoadDistanceMiles) mi. If none are close enough, falls back to the nearest station."
        default:
            return ""
        }
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Stepper("Show \(nearbyCount) stations", value: $nearbyCount, in: 1...25)
                    Text("Controls how many nearby stations appear at the top of the station list when location access is enabled. Increase this if you live near several stations you use regularly, or reduce it to keep the list tidy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Nearby Stations")
            } footer: {
                helpLink("nearby-stations")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Show Next Service", isOn: $showNextServiceOnFavourites)
                    Text("Displays the next scheduled departure time on each favourite card, so you can see at a glance how long you have before your next train — without opening the full board.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if showNextServiceOnFavourites {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Tap to Jump to Service", isOn: $nextServiceTappable)
                        Text("When enabled, tapping the next departure time on a favourites card opens the full service detail — calling points, live delays, and platform. Turn this off if you prefer taps to open the full board instead.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Split-Flap Refresh", isOn: $splitFlapRefresh)
                        Text("Animates departure times with a split-flap board effect whenever live data refreshes. Satisfying to watch, but turn this off if you find the motion distracting or want to reduce battery use.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Favourites")
            } footer: {
                helpLink("favourites")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("On Launch", selection: $autoLoadMode) {
                        Text("Disabled").tag("off")
                        Text("Nearest Station").tag("nearest")
                        Text("Nearby Favourite").tag("favourite")
                        Text("Favourite, then Nearest").tag("favouriteOrNearest")
                    }
                    if autoLoadMode == "favourite" || autoLoadMode == "favouriteOrNearest" {
                        Stepper("Within \(autoLoadDistanceMiles) mi", value: $autoLoadDistanceMiles, in: 1...50)
                    }
                    Text(autoLoadModeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if autoLoadMode == "favourite" || autoLoadMode == "favouriteOrNearest" {
                        Text("When multiple favourites are within range, the one highest in your favourites list is loaded — not the closest. Reorder your favourites to control which board opens first.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Auto-Load on Launch")
            } footer: {
                helpLink("auto-load")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Station Names in Small Caps", isOn: $stationNamesSmallCaps)
                    Text("Renders station names throughout the app in small capitals — a more compact typographic style that some people find easier to scan on a long list. This is purely cosmetic and has no effect on functionality.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Operator Colours", selection: $operatorColourStyleRaw) {
                        ForEach(OperatorColourStyle.allCases, id: \.rawValue) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    }
                    Group {
                        switch OperatorColourStyle(rawValue: operatorColourStyleRaw) ?? .none {
                        case .none:
                            Text("No operator colour coding. All rows use the standard background.")
                        case .subtle:
                            Text("A thin coloured strip on the left edge of each row shows the operator's brand colour — understated but easy to spot.")
                        case .colourful:
                            Text("Each row gets a soft tint of the operator's brand colour as its background — colourful without being overwhelming.")
                        case .gradient:
                            Text("A gradient sweeps from the operator's brand colour on the left to the cell background on the right — the time sits in full colour, the rest fades naturally.")
                        case .vibrant:
                            Text("Rows are fully filled with the operator's brand colour. Bold and eye-catching.")
                        case .preview:
                            Text("Cycles through all four styles on consecutive rows so you can compare them at once.")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("Appearance")
            } footer: {
                helpLink("appearance")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Show Recent Filters", isOn: $showRecentFilters)
                    Text("When you filter a board to show trains to or from a specific station, that filter is saved so you can reapply it quickly next time. The count controls how many past filters are remembered — older ones are dropped once the list is full.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if showRecentFilters {
                    Stepper("Keep \(recentFilterCount) recent", value: $recentFilterCount, in: 1...10)
                }
            } header: {
                Text("Recent Filters")
            } footer: {
                helpLink("recent-filters")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Open in", selection: $mapsProvider) {
                        Text("Apple Maps").tag("apple")
                        Text("Google Maps").tag("google")
                    }
                    Text("Choose which maps app opens when you tap a station's location — for example from the station information sheet. Google Maps must be installed for that option to work.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Maps")
            } footer: {
                helpLink("maps")
            }

            Section {
                HStack {
                    Text("Last Updated")
                    Spacer()
                    if let lastRefresh {
                        Text("\(lastRefresh, style: .relative) ago")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Stations")
                    Spacer()
                    Text("\(viewModel.stations.count)")
                        .foregroundStyle(.secondary)
                }

                Button {
                    isRefreshing = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task {
                        await viewModel.forceRefresh()
                        lastRefresh = StationCache.lastRefreshDate()
                        isRefreshing = false
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                } label: {
                    HStack {
                        Text("Refresh Now")
                        Spacer()
                        if isRefreshing {
                            ProgressView()
                        }
                    }
                }
                .disabled(isRefreshing)
            } header: {
                Text("Station Data")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("The app caches a list of all UK stations so searches work instantly and offline. This data changes rarely — new stations, closures, or name changes — so a manual refresh is only needed if something looks out of date.")
                    helpLink("station-data")
                }
            }
            Section {
                Button {
                    let boards = (try? JSONDecoder().decode([String].self, from: favouriteBoardsData)) ?? []
                    let export = FavouritesExport(favourites: boards)
                    if let data = try? JSONEncoder().encode(export) {
                        exportDocument = FavouritesDocument(data: data)
                        showingExporter = true
                    }
                } label: {
                    Label("Export Favourites", systemImage: "square.and.arrow.up")
                }

                Button {
                    importResult = nil
                    showingImporter = true
                } label: {
                    Label("Import Favourites", systemImage: "square.and.arrow.down")
                }

                if let result = importResult {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.message)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(result.rejected.isEmpty ? AnyShapeStyle(.primary) : AnyShapeStyle(.red))

                        ForEach(result.imported, id: \.self) { item in
                            Label(item, systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.multicolor)
                        }

                        if !result.skipped.isEmpty {
                            Text(result.skipped.count == 1 ? "Already in your favourites:" : "Already in your favourites — skipped:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, result.imported.isEmpty ? 0 : 4)
                            ForEach(result.skipped, id: \.self) { item in
                                Label(item, systemImage: "minus.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !result.rejected.isEmpty {
                            Text(result.rejected.count == 1 ? "Rejected — not added:" : "Rejected — not added:")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                                .padding(.top, (result.imported.isEmpty && result.skipped.isEmpty) ? 0 : 4)
                            ForEach(result.rejected, id: \.id) { item in
                                VStack(alignment: .leading, spacing: 1) {
                                    Label(item.id, systemImage: "xmark.circle.fill")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.red)
                                        .symbolRenderingMode(.multicolor)
                                    Text(item.reason)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 20)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Favourites Backup")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export saves all your favourite boards to a JSON file you can share or back up. Import reads a file and appends any favourites not already in your list — existing favourites are never overwritten or removed.\n\nYou can also craft a file by hand. Format: {\"favourites\":[\"MAN-dep\",\"LDS-arr\",\"LIV-dep-to-EUS\"]}. Each entry is CRS-dep or CRS-arr, with an optional -to-CRS or -from-CRS suffix for filtered boards.")
                    HStack(spacing: 12) {
                        helpLink("backup")
                        helpLink("json-format")
                    }
                }
            }

            Section {
                urlSchemeRow(title: "Departures board", description: "Open the departures board for any station.", url: "departure://departures/MAN")
                urlSchemeRow(title: "Arrivals board", description: "Open the arrivals board instead of departures.", url: "departure://arrivals/LDS")
                urlSchemeRow(title: "Station information", description: "Open the station info sheet — facilities, access, parking, and more.", url: "departure://station/YRK")
                urlSchemeRow(title: "Filtered departures — trains to a destination", description: "Show only trains going to a specific station. Great for commute shortcuts.", url: "departure://departures/LIV?filter=EUS&filterType=to")
                urlSchemeRow(title: "Filtered arrivals — trains from an origin", description: "Show only arrivals coming from a specific station. filterType=from is the default so it can be omitted.", url: "departure://arrivals/EUS?filter=LIV")
                liveServiceRow()
            } header: {
                Label("URL Schemes", systemImage: "link")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("URL schemes let you open the app directly to any board from Safari, the Shortcuts app, or any other app that supports custom links.\n\nUse them to build home screen bookmarks, widgets, or automations — for example a Shortcut that opens your morning commute board with one tap, or a Safari bookmark that jumps straight to your local station.\n\nFiltered boards narrow the board to trains between two specific stations — perfect if you only care about one route. Add ?filter={CRS} to filter by a station. The optional filterType parameter controls the direction: from (default) shows trains originating from that station, to shows trains going there.\n\nReplace station codes with any three-letter CRS code, shown in grey beneath every station name in the app. Tap any example to open it, or long press to copy the URL.")
                    helpLink("url-schemes")
                }
            }
            .task {
                guard liveServiceExample == nil else { return }
                if let board = try? await StationViewModel.fetchBoard(for: "MAN"),
                   let service = board.trainServices?.first,
                   let destination = service.destination.first?.locationName {
                    liveServiceExample = LiveServiceExample(
                        crs: "MAN",
                        stationName: "Manchester Piccadilly",
                        serviceId: service.serviceId,
                        destination: destination,
                        scheduledTime: service.std ?? service.sta ?? ""
                    )
                }
            }

            if showDebug {
                Section("Debug") {
                    HStack {
                        Text("API")
                        Spacer()
                        Text(APIConfig.baseURL)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            }

            // Created by — plain text, tapping 10 times reveals the debug section
            Section {
                Text("Created by Daniel Breslan")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .onTapGesture {
                        debugTapCount += 1
                        debugTapResetTask?.cancel()
                        if debugTapCount >= 10 {
                            debugTapCount = 0
                            showDebug = true
                        } else {
                            debugTapResetTask = Task {
                                try? await Task.sleep(for: .seconds(2))
                                if !Task.isCancelled { debugTapCount = 0 }
                            }
                        }
                    }
            }
        }
        .navigationTitle("Settings")
        .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .json, defaultFilename: "departure-board-favourites") { _ in }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                importFavourites(from: url)
            case .failure:
                importResult = ImportResult(message: "Failed to open file.", imported: [], skipped: [], rejected: [])
            }
        }
    }

    private func importFavourites(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importResult = ImportResult(message: "Permission denied.", imported: [], skipped: [], rejected: [])
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else {
            importResult = ImportResult(message: "Couldn't read the file.", imported: [], skipped: [], rejected: [])
            return
        }
        guard let fileContents = try? JSONDecoder().decode(FavouritesExport.self, from: data) else {
            importResult = ImportResult(message: "File isn't a valid Departure Board export. Expected JSON with a \"favourites\" array.", imported: [], skipped: [], rejected: [])
            return
        }
        guard !fileContents.favourites.isEmpty else {
            importResult = ImportResult(message: "The file contained no favourites.", imported: [], skipped: [], rejected: [])
            return
        }

        var current = (try? JSONDecoder().decode([String].self, from: favouriteBoardsData)) ?? []
        let existing = Set(current)
        let allStations = viewModel.stations

        var imported: [String] = []
        var skipped: [String] = []
        var rejected: [(id: String, reason: String)] = []

        for id in fileContents.favourites {
            // Already in the list — skip without error
            if existing.contains(id) {
                skipped.append(describeBoardID(id) ?? id)
                continue
            }

            // Must parse as a valid board ID structure
            guard let parsed = SharedDefaults.parseBoardID(id) else {
                rejected.append((id, "Not a valid board ID format"))
                continue
            }

            // Primary station must exist
            guard allStations.contains(where: { $0.crsCode == parsed.crs }) else {
                rejected.append((id, "Unknown station code \"\(parsed.crs)\""))
                continue
            }

            // Filter station (if present) must also exist
            if let filterCrs = parsed.filterCrs {
                guard allStations.contains(where: { $0.crsCode == filterCrs }) else {
                    rejected.append((id, "Unknown filter station code \"\(filterCrs)\""))
                    continue
                }
            }

            // Valid — add it
            current.append(id)
            imported.append(describeBoardID(id) ?? id)
        }

        if let encoded = try? JSONEncoder().encode(current) {
            favouriteBoardsData = encoded
        }

        let total = fileContents.favourites.count
        let summary: String
        if imported.isEmpty && rejected.isEmpty {
            summary = "All \(total) entr\(total == 1 ? "y" : "ies") already in your favourites — nothing added."
        } else if imported.isEmpty {
            summary = "Nothing imported — \(rejected.count) entr\(rejected.count == 1 ? "y" : "ies") rejected."
        } else {
            summary = "Imported \(imported.count) of \(total) favourite\(total == 1 ? "" : "s")."
        }

        importResult = ImportResult(message: summary, imported: imported, skipped: skipped, rejected: rejected)
    }

    private func describeBoardID(_ id: String) -> String? {
        guard let parsed = SharedDefaults.parseBoardID(id) else { return nil }
        let stationName = viewModel.stations.first(where: { $0.crsCode == parsed.crs })?.name ?? parsed.crs
        let bt = parsed.boardType == .departures ? "Departures" : "Arrivals"
        if let filterCrs = parsed.filterCrs, let filterType = parsed.filterType {
            let filterName = viewModel.stations.first(where: { $0.crsCode == filterCrs })?.name ?? filterCrs
            let arrow = filterType == "to" ? "→" : "←"
            return "\(stationName) \(bt) \(arrow) \(filterName)"
        }
        return "\(stationName) · \(bt)"
    }

    @ViewBuilder
    private func helpLink(_ anchor: String) -> some View {
        let origin = URL(string: APIConfig.baseURL).flatMap { url in
            url.host.map { "https://\($0)" }
        } ?? "https://rail.breslan.co.uk"
        Link("Read more…", destination: URL(string: "\(origin)/help#\(anchor)")!)
            .font(.caption)
    }

    @ViewBuilder
    private func urlSchemeRow(title: String, description: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(url)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.brand)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let u = URL(string: url) { UIApplication.shared.open(u) }
        }
        .contextMenu {
            Button { UIPasteboard.general.string = url } label: {
                Label("Copy URL", systemImage: "doc.on.doc")
            }
            Button {
                if let u = URL(string: url) { UIApplication.shared.open(u) }
            } label: {
                Label("Open", systemImage: "arrow.up.right.square")
            }
        }
    }

    @ViewBuilder
    private func liveServiceRow() -> some View {
        if let live = liveServiceExample {
            let url = "departure://service/\(live.crs)/\(live.serviceId)"
            VStack(alignment: .leading, spacing: 2) {
                Text("Jump to a specific service")
                    .font(.subheadline)
                Text("The \(live.scheduledTime) service from \(live.stationName) to \(live.destination) has the ID below — tap to open it directly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(url)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.brand)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let u = URL(string: url) { UIApplication.shared.open(u) }
            }
            .contextMenu {
                Button { UIPasteboard.general.string = url } label: {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }
                Button {
                    if let u = URL(string: url) { UIApplication.shared.open(u) }
                } label: {
                    Label("Open", systemImage: "arrow.up.right.square")
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Jump to a specific service")
                    .font(.subheadline)
                Text("Open any individual service directly using its service ID.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("departure://service/{crs}/{serviceId}")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.brand)
                    .opacity(0.5)
            }
            .overlay(alignment: .trailing) {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    private struct LiveServiceExample {
        let crs: String
        let stationName: String
        let serviceId: String
        let destination: String
        let scheduledTime: String
    }
}

private struct FavouritesExport: Codable {
    var favourites: [String]
}

struct FavouritesDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
