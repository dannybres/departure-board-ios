//
//  SettingsView.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {

    @ObservedObject var viewModel: StationViewModel
    @StateObject private var trial = TrialManager.shared
    @EnvironmentObject private var entitlement: EntitlementManager
    @AppStorage("nearbyStationCount") var nearbyCount: Int = 5
    @AppStorage("recentFilterCount") var recentFilterCount: Int = 3
    @AppStorage("showRecentFilters") var showRecentFilters: Bool = true
    @AppStorage("mapsProvider") var mapsProvider: String = "apple"
    @AppStorage("showNextServiceOnFavourites") var showNextServiceOnFavourites: Bool = true
    @AppStorage("nextServiceTappable") var nextServiceTappable: Bool = false
    @AppStorage("splitFlapRefresh") var splitFlapRefresh: Bool = false
    @AppStorage("stationNamesSmallCaps") var stationNamesSmallCaps: Bool = false
    @AppStorage(SharedDefaults.Keys.rowTheme) var rowThemeRaw: String = RowTheme.none.rawValue
    @AppStorage(SharedDefaults.Keys.colourVibrancy) var colourVibrancyRaw: String = ColourVibrancy.vibrant.rawValue
    @AppStorage(SharedDefaults.Keys.widgetRowTheme, store: SharedDefaults.shared) var widgetRowThemeRaw: String = "none"
    @AppStorage(SharedDefaults.Keys.widgetColourMode, store: SharedDefaults.shared) var widgetColourMode: String = "brand"
    @AppStorage(SharedDefaults.Keys.widgetSplitFlap, store: SharedDefaults.shared) var widgetSplitFlap: Bool = false
    @AppStorage("autoLoadMode") var autoLoadMode: String = "off"
    @AppStorage("autoLoadDistanceMiles") var autoLoadDistanceMiles: Int = 2
    @AppStorage(SharedDefaults.Keys.favouriteBoards, store: SharedDefaults.shared) private var favouriteBoardsData: Data = Data()
    @AppStorage(AwarenessSettingsKeys.siriSuggestionsEnabled) private var siriSuggestionsEnabled: Bool = true
    @AppStorage(AwarenessSettingsKeys.spotlightStationsEnabled) private var spotlightStationsEnabled: Bool = true
    @AppStorage(AwarenessSettingsKeys.spotlightFavouritesEnabled) private var spotlightFavouritesEnabled: Bool = true
    @State private var isRefreshing = false
    @State private var debugTapCount = 0
    @State private var debugTapResetTask: Task<Void, Never>? = nil
    @State private var showDebug = false
    @State private var showSupportCodeSheet = false
    @State private var supportCodeInput = ""
    @FocusState private var supportCodeFieldFocused: Bool
    @State private var supportMessage: String?
    @State private var showSupportMessage = false
    @State private var releaseCardImage: UIImage? = nil
    @State private var showReleaseCardShare = false
    @State private var lastRefresh: Date? = StationCache.lastRefreshDate()
    @State private var liveServiceExample: LiveServiceExample? = nil
    @State private var themePreviewService: Service? = nil
    @State private var themePreviewIsLoading: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var exportDocument = FavouritesDocument(data: Data())
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var importResult: ImportResult? = nil
    @State private var showSubscribe = false
    @State private var subscribeFeature: PaywallFeature = .all
    @State private var awarenessMessage: String?
    @State private var showAwarenessMessage = false
    @State private var cachedBoards: [BoardCacheStore.CachedBoardSummary] = []
    @State private var cachedServices: [ServiceCacheStore.CachedServiceSummary] = []
    @State private var lastAllowedAutoLoadMode: String = "off"
    private let freeNearbyLimit = 3
    private let debugMenuCode = "Everton"
    // Suggested support code for redeeming the one-time second trial.
    private let secondTrialSupportCode = "DB-SECOND-TRIAL-2026"

    private struct ImportResult {
        let message: String
        let imported: [String]                      // human-readable label of each added board
        let skipped: [String]                       // human-readable label of each already-present board
        let rejected: [(id: String, reason: String)] // raw ID + explicit rejection reason
    }

    private var hasPremiumAccess: Bool {
        entitlement.hasPremiumAccess
    }

    private func requirePremium(_ feature: PaywallFeature = .all) -> Bool {
        guard hasPremiumAccess else {
            subscribeFeature = feature
            showSubscribe = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return false
        }
        return true
    }

    private func handleSupportCodeSubmission() {
        let code = supportCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        showSupportCodeSheet = false

        if code.caseInsensitiveCompare(debugMenuCode) == .orderedSame {
            showDebug = true
            return
        }

        if code == secondTrialSupportCode {
            let redeemed = TrialManager.shared.redeemSecondTrialIfAvailable()
            supportMessage = redeemed
                ? "Second trial activated."
                : "All trials have been used."
            showSupportMessage = true
            return
        }

        supportMessage = "Code incorrect."
        showSupportMessage = true
    }

    @MainActor
    private func shareReleaseCard() {
        let card = ReleaseCardShareView()
            .frame(width: 1080, height: 1350)
            .background(Color.black)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 1
        if let image = renderer.uiImage {
            releaseCardImage = image
            showReleaseCardShare = true
        } else {
            supportMessage = "Failed to render release card."
            showSupportMessage = true
        }
    }

    private var autoLoadModeDescription: String {
        if !entitlement.hasPremiumAccess && (autoLoadMode == "favourite" || autoLoadMode == "favouriteOrNearest") {
            return "This auto-load mode is a Departure Board Pro feature. During free mode, auto-load falls back to Disabled."
        }
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

    private func rebuildAwarenessIndex() {
        let stations = viewModel.stations.isEmpty ? (StationCache.load() ?? []) : viewModel.stations
        let boards = (try? JSONDecoder().decode([String].self, from: favouriteBoardsData)) ?? []
        SpotlightIndexer.shared.rebuildAll(stations: stations, boardIDs: boards)
        awarenessMessage = "Siri and Spotlight index rebuilt."
        showAwarenessMessage = true
    }

    private func clearAwarenessData() {
        SpotlightIndexer.shared.clearAll()
        ActivityDonor.shared.clearDonations()
        RoutineEngine.shared.clearHistory()
        awarenessMessage = "Siri and Spotlight history cleared."
        showAwarenessMessage = true
    }

    private func refreshCachedBoards() {
        cachedBoards = BoardCacheStore.shared.listCachedBoards()
    }

    private func clearCachedBoards() {
        BoardCacheStore.shared.clearAll()
        refreshCachedBoards()
    }

    private func refreshCachedServices() {
        cachedServices = ServiceCacheStore.shared.listCachedServices()
    }

    private func clearCachedServices() {
        ServiceCacheStore.shared.clearAll()
        refreshCachedServices()
    }

    var body: some View {
        Form {
            TrialBannerSection(daysRemaining: trial.daysRemaining, isExpired: trial.isExpired, hasSubscription: entitlement.hasSubscription)

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Stepper("Show \(hasPremiumAccess ? nearbyCount : min(nearbyCount, freeNearbyLimit)) stations", value: $nearbyCount, in: 1...25)
                        .disabled(!hasPremiumAccess)
                    if hasPremiumAccess {
                        Text("Controls how many nearby stations appear at the top of the station list when location access is enabled. Increase this if you live near several stations you use regularly, or reduce it to keep the list tidy.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        PremiumLockedDescription(text: "Free mode is capped at 3 nearby stations. Get Departure Board Pro to choose any value up to 25.")
                    }
                }
            } header: {
                Text("Nearby Stations")
            } footer: {
                helpLink("nearby-stations")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Show Next Service", isOn: $showNextServiceOnFavourites)
                    if hasPremiumAccess {
                        Text("Displays the next scheduled departure time on each favourite card, so you can see at a glance how long you have before your next train — without opening the full board.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        PremiumLockedDescription(text: "Displays the next scheduled departure time on each favourite card, so you can see at a glance how long you have before your next train — without opening the full board.")
                    }
                }
                .disabled(!hasPremiumAccess)
                if showNextServiceOnFavourites {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Tap to Jump to Service", isOn: $nextServiceTappable)
                        if hasPremiumAccess {
                            Text("When enabled, tapping the next departure time on a favourites card opens the full service detail — calling points, live delays, and platform. Turn this off if you prefer taps to open the full board instead.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            PremiumLockedDescription(text: "When enabled, tapping the next departure time on a favourites card opens the full service detail — calling points, live delays, and platform. Turn this off if you prefer taps to open the full board instead.")
                        }
                    }
                    .disabled(!hasPremiumAccess)
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Split-Flap Refresh", isOn: $splitFlapRefresh)
                            .disabled(reduceMotion || !hasPremiumAccess)
                        if hasPremiumAccess {
                            Text(reduceMotion
                                ? "Unavailable because Reduce Motion is enabled in Accessibility settings."
                                : "Animates departure times with a split-flap board effect whenever live data refreshes. Satisfying to watch, but turn this off if you find the motion distracting or want to reduce battery use.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            PremiumLockedDescription(text: "Animates departure times with a split-flap board effect whenever live data refreshes. Satisfying to watch, but turn this off if you find the motion distracting or want to reduce battery use.")
                        }
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
                    if !hasPremiumAccess && (autoLoadMode == "favourite" || autoLoadMode == "favouriteOrNearest") {
                        PremiumLockedDescription(text: "Smart auto-load modes require Departure Board Pro.")
                    }
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
                        .disabled(!hasPremiumAccess)
                    if hasPremiumAccess {
                        Text("Renders station names throughout the app in small capitals — a more compact typographic style that some people find easier to scan on a long list. This is purely cosmetic and has no effect on functionality.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        PremiumLockedDescription(text: "Small caps requires Pro. Your current choice is saved and restored when Pro is active.")
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Row Theme", selection: $rowThemeRaw) {
                        ForEach(RowTheme.allCases, id: \.rawValue) { theme in
                            Text(theme.displayName).tag(theme.rawValue)
                        }
                    }
                    .disabled(!hasPremiumAccess)
                    Group {
                        switch hasPremiumAccess ? (RowTheme(rawValue: rowThemeRaw) ?? .none) : .none {
                        case .none:
                            Text("No operator colour coding. All rows use the standard background.")
                        case .trackline:
                            Text("A thin stripe on the left edge of each row shows the operator's colour — barely-there but easy to spot once you know it's there.")
                        case .signalRail:
                            Text("A slim coloured line sits between the time and the destination — a subtle nod to the operator without taking up much space.")
                        case .timeTile:
                            Text("The departure time sits inside a small coloured block — a neat pop of brand colour right where your eye goes first.")
                        case .timePanel:
                            Text("The left side of each row, behind the departure time, is filled with the operator's colour — like a classic departure board.")
                        case .platformPulse:
                            Text("The platform badge takes on the operator's colour. A small dot appears in its place when no platform has been allocated yet.")
                        case .boardWash:
                            Text("The entire row background is filled with the operator's colour. Bold, vivid, and impossible to miss.")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Colour Vibrancy", selection: $colourVibrancyRaw) {
                        ForEach(ColourVibrancy.allCases, id: \.rawValue) { vibrancy in
                            Text(vibrancy.displayName).tag(vibrancy.rawValue)
                        }
                    }
                    .disabled(!hasPremiumAccess)
                    Group {
                        switch ColourVibrancy(rawValue: colourVibrancyRaw) ?? .vibrant {
                        case .vibrant:
                            Text("Operator colours are shown at full strength — vivid and bold.")
                        case .tinted:
                            Text("Operator colours are softened to a gentle wash — present but easy on the eye.")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                if !hasPremiumAccess {
                    PremiumLockedDescription(text: "Operator livery themes are disabled in free mode. Your selected theme is saved and restored when Pro is active.")
                }
            } header: {
                Text("Appearance")
            } footer: {
                helpLink("appearance")
            }

            Section {
                themePreviewRow()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Widget Row Theme", selection: $widgetRowThemeRaw) {
                        ForEach(WidgetTheme.allCases, id: \.rawValue) { theme in
                            Text(theme.displayName).tag(theme.rawValue)
                        }
                    }
                    .disabled(!hasPremiumAccess)
                    Group {
                        switch hasPremiumAccess ? (WidgetTheme(rawValue: widgetRowThemeRaw) ?? .none) : .none {
                        case .none:
                            Text("Plain rows with no colour accent.")
                        case .trackline:
                            Text("A thin coloured stripe on the left edge of each row.")
                        case .signalRail:
                            Text("A slim coloured line sits between the time and destination.")
                        case .timeTile:
                            Text("The departure time sits inside a small coloured block.")
                        case .platformPulse:
                            Text("The platform badge is filled with the accent colour.")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Colour Source", selection: $widgetColourMode) {
                        Text("Brand Colour").tag("brand")
                        Text("Operator Colours").tag("operator")
                    }
                    .disabled(!hasPremiumAccess)
                    if hasPremiumAccess {
                        Text("Use the app's brand colour for all accents, or each train operator's own livery colours.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        PremiumLockedDescription(text: "Operator colours in widgets require Departure Board Pro. Free mode always displays the plain style.")
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Split-Flap Animations", isOn: $widgetSplitFlap)
                        .disabled(!hasPremiumAccess)
                    if hasPremiumAccess {
                        Text("Rows animate with a split-flap push effect whenever the widget refreshes or a service drops off the board.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        PremiumLockedDescription(text: "Widget split-flap animations require Departure Board Pro.")
                    }
                }
            } header: {
                Text("Widget Appearance")
            } footer: {
                Text("Configured separately from the board view.")
            }

            Section {
                widgetPreviewSection()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
                    guard requirePremium(.favourites) else { return }
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
                    guard requirePremium(.favourites) else { return }
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
                    if hasPremiumAccess {
                        Text("Export saves all your favourite boards to a JSON file you can share or back up. Import reads a file and appends any favourites not already in your list — existing favourites are never overwritten or removed.\n\nYou can also craft a file by hand. Format: {\"favourites\":[\"MAN-dep\",\"LDS-arr\",\"LIV-dep-to-EUS\"]}. Each entry is CRS-dep or CRS-arr, with an optional -to-CRS or -from-CRS suffix for filtered boards.")
                    } else {
                        PremiumLockedDescription(text: "Favourites backup requires Departure Board Pro.")
                    }
                    helpLink("backup")
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

            Section {
                Toggle("Siri Suggestions", isOn: $siriSuggestionsEnabled)
                Toggle("Search Stations in Spotlight", isOn: $spotlightStationsEnabled)
                Toggle("Search Favourites in Spotlight", isOn: $spotlightFavouritesEnabled)
                Button("Rebuild Siri & Spotlight Index") {
                    rebuildAwarenessIndex()
                }
                Button("Clear Siri & Spotlight Data", role: .destructive) {
                    clearAwarenessData()
                }
            } header: {
                Text("Siri & Search")
            } footer: {
                Text("Controls whether Departure Board appears in Siri suggestions and Spotlight search. Clearing removes donated suggestions and local routine history.")
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
                    HStack {
                        Text("Trial Start")
                        Spacer()
                        Text(trial.firstLaunchDate.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    HStack(spacing: 12) {
                        Button("− 5 Days") { TrialManager.shared.shiftForDebug(days: -5) }
                            .buttonStyle(.bordered)
                        Button("+ 5 Days") { TrialManager.shared.shiftForDebug(days: 5) }
                            .buttonStyle(.bordered)
                        Button("Reset 2nd Trial") {
                            TrialManager.shared.resetSecondTrialForDebug()
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        Button(role: .destructive) {
                            TrialManager.shared.resetForDebug()
                        } label: {
                            Text("Reset")
                        }
                        .buttonStyle(.bordered)
                    }
                    HStack(spacing: 12) {
                        Button("Subscription Active") {
                            entitlement.setSubscriptionActive(true)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Subscription Inactive") {
                            entitlement.setSubscriptionActive(false)
                        }
                        .buttonStyle(.bordered)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Cached Boards")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("Refresh") {
                                refreshCachedBoards()
                            }
                            .buttonStyle(.bordered)
                        }

                        if cachedBoards.isEmpty {
                            Text("No cached boards.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(cachedBoards) { cached in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(cached.locationName) (\(cached.key.crs))")
                                        .font(.caption.weight(.semibold))
                                    Text("\(cached.key.boardType.rawValue.capitalized)\(cached.key.filterCrs.map { " • \((cached.key.filterType ?? "to").uppercased()) \($0)" } ?? "")")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("Cached \(ContentView.fuzzyLabel(from: cached.loadedAt, tick: Date()))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                            Button(role: .destructive) {
                                clearCachedBoards()
                            } label: {
                                Text("Clear All Cached Boards")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Cached Services")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("Refresh") {
                                refreshCachedServices()
                            }
                            .buttonStyle(.bordered)
                        }

                        if cachedServices.isEmpty {
                            Text("No cached services.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(cachedServices) { cached in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(cached.scheduled) \(cached.boardType == .arrivals ? cached.originName : cached.destinationName)")
                                        .font(.caption.weight(.semibold))
                                    Text("\(cached.boardType.rawValue.capitalized) • \(cached.locationName) • \(cached.key.serviceID)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    Text("Cached \(ContentView.fuzzyLabel(from: cached.loadedAt, tick: Date()))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                            Button(role: .destructive) {
                                clearCachedServices()
                            } label: {
                                Text("Clear All Cached Services")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    Button {
                        shareReleaseCard()
                    } label: {
                        Label("Share 1.0 Card", systemImage: "square.and.arrow.up")
                    }
                }
                .onAppear {
                    refreshCachedBoards()
                    refreshCachedServices()
                }
            }

            // Created by — tap 10 times to open support code entry.
            Section {
                Text("Created by Daniel Breslan")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .onTapGesture {
                        debugTapCount += 1
                        debugTapResetTask?.cancel()
                        if debugTapCount >= 3 {
                            debugTapCount = 0
                            supportCodeInput = ""
                            showSupportCodeSheet = true
                        } else {
                            debugTapResetTask = Task {
                                try? await Task.sleep(for: .seconds(2))
                                if !Task.isCancelled { debugTapCount = 0 }
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showSubscribe) {
            SubscribeView(initialFeature: subscribeFeature)
        }
        .sheet(isPresented: $showSupportCodeSheet) {
            NavigationStack {
                Form {
                    Section("Enter Support Code") {
                        TextField("Code", text: $supportCodeInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($supportCodeFieldFocused)
                    }
                }
                .navigationTitle("Support")
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        supportCodeFieldFocused = true
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showSupportCodeSheet = false
                            supportCodeFieldFocused = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") {
                            handleSupportCodeSubmission()
                            supportCodeFieldFocused = false
                        }
                        .disabled(supportCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showReleaseCardShare) {
            if let image = releaseCardImage {
                ActivityShareSheet(activityItems: [image])
            }
        }
        .alert("Support", isPresented: $showSupportMessage, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(supportMessage ?? "")
        })
        .alert("Siri & Search", isPresented: $showAwarenessMessage, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(awarenessMessage ?? "")
        })
        .onAppear {
            lastAllowedAutoLoadMode = autoLoadMode == "nearest" ? "nearest" : "off"
        }
        .onChange(of: siriSuggestionsEnabled) {
            if !siriSuggestionsEnabled {
                ActivityDonor.shared.clearDonations()
            }
        }
        .onChange(of: spotlightStationsEnabled) {
            if spotlightStationsEnabled {
                let stations = viewModel.stations.isEmpty ? (StationCache.load() ?? []) : viewModel.stations
                SpotlightIndexer.shared.indexStations(stations)
            } else {
                SpotlightIndexer.shared.clearAll()
                let boards = (try? JSONDecoder().decode([String].self, from: favouriteBoardsData)) ?? []
                SpotlightIndexer.shared.indexFavouriteBoards(boards, stations: viewModel.stations)
            }
        }
        .onChange(of: spotlightFavouritesEnabled) {
            if spotlightFavouritesEnabled {
                let boards = (try? JSONDecoder().decode([String].self, from: favouriteBoardsData)) ?? []
                SpotlightIndexer.shared.indexFavouriteBoards(boards, stations: viewModel.stations)
            } else {
                SpotlightIndexer.shared.clearAll()
                let stations = viewModel.stations.isEmpty ? (StationCache.load() ?? []) : viewModel.stations
                SpotlightIndexer.shared.indexStations(stations)
            }
        }
        .onChange(of: autoLoadMode) {
            guard !hasPremiumAccess else {
                lastAllowedAutoLoadMode = autoLoadMode
                return
            }
            if autoLoadMode == "favourite" || autoLoadMode == "favouriteOrNearest" {
                subscribeFeature = .autoLoad
                showSubscribe = true
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                autoLoadMode = lastAllowedAutoLoadMode
            } else if autoLoadMode == "off" || autoLoadMode == "nearest" {
                lastAllowedAutoLoadMode = autoLoadMode
            } else {
                autoLoadMode = lastAllowedAutoLoadMode
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

    // MARK: - Widget Preview

    private struct WidgetPreviewService {
        let scheduled: String
        let destination: String
        let platform: String?
        let status: String
        let isCancelled: Bool
        let isDelayed: Bool
        let operatorCode: String
    }

    private let widgetMockServices: [WidgetPreviewService] = [
        .init(scheduled: "08:32", destination: "London Paddington",    platform: "3",   status: "On time",   isCancelled: false, isDelayed: false, operatorCode: "GW"),
        .init(scheduled: "08:47", destination: "Manchester Piccadilly", platform: "7",   status: "09:02",     isCancelled: false, isDelayed: true,  operatorCode: "TP"),
        .init(scheduled: "09:15", destination: "Edinburgh Waverley",    platform: nil,   status: "On time",   isCancelled: false, isDelayed: false, operatorCode: "SR"),
        .init(scheduled: "09:28", destination: "Birmingham New St",     platform: "1",   status: "Cancelled", isCancelled: true,  isDelayed: false, operatorCode: "VT"),
    ]

    @ViewBuilder
    private func widgetPreviewSection() -> some View {
        let theme = hasPremiumAccess ? (WidgetTheme(rawValue: widgetRowThemeRaw) ?? .none) : .none
        VStack(alignment: .leading, spacing: 0) {
            // Widget chrome header
            HStack(alignment: .center) {
                Text("London Waterloo")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.brand)
                Spacer(minLength: 0)
                Text("just now")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            .padding(.bottom, 8)

            ForEach(Array(widgetMockServices.enumerated()), id: \.offset) { _, service in
                widgetPreviewRow(service, theme: theme, useOperatorColours: hasPremiumAccess && widgetColourMode == "operator")
                    .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .animation(.default, value: widgetRowThemeRaw)
        .animation(.default, value: widgetColourMode)
    }

    @ViewBuilder
    private func widgetPreviewRow(_ service: WidgetPreviewService, theme: WidgetTheme, useOperatorColours: Bool = false) -> some View {
        WidgetPreviewRowContent(service: service, theme: theme, useOperatorColours: useOperatorColours)
    }

    private struct WidgetPreviewRowContent: View {
        let service: WidgetPreviewService
        let theme: WidgetTheme
        let useOperatorColours: Bool
        @Environment(\.colorScheme) private var colorScheme

        private var accent: Color {
            useOperatorColours ? OperatorColours.entry(for: service.operatorCode).primary : Theme.brand
        }
        private var accentIsLight: Bool {
            useOperatorColours && OperatorColours.entry(for: service.operatorCode).primaryIsLight
        }

        var body: some View {
            HStack(spacing: 0) {
                if theme == .trackline {
                    accent
                        .frame(width: 2)
                        .padding(.vertical, 1)
                        .padding(.trailing, 5)
                }

                let timeFg: Color = theme == .timeTile
                    ? (accentIsLight ? .black : .white)
                    : .primary
                let timeText = Text(service.scheduled)
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(timeFg)
                    .lineLimit(1)
                    .fixedSize()

                if theme == .timeTile {
                    timeText
                        .padding(.vertical, 1)
                        .padding(.horizontal, 3)
                        .background(accent, in: RoundedRectangle(cornerRadius: 3))
                        .padding(.trailing, 5)
                } else {
                    timeText.frame(width: 36, alignment: .leading)
                }

                if theme == .signalRail {
                    accent
                        .frame(width: 1.5)
                        .padding(.vertical, 1)
                        .padding(.horizontal, 4)
                }

                Text(service.destination)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(service.isCancelled ? Color(.label).opacity(0.45) : Color(.label))

                Spacer(minLength: 0)

                if service.isCancelled {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else if service.isDelayed {
                    Text(service.status)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.orange)
                }

                if let platform = service.platform {
                    let badgeBg: Color = theme == .platformPulse
                        ? accent
                        : Color(colorScheme == .dark ? UIColor.systemGray : UIColor.systemGray2)
                    let badgeFg: Color = theme == .platformPulse
                        ? (accentIsLight ? .black : .white)
                        : (colorScheme == .dark ? .black : .white)
                    Text(platform)
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(badgeFg)
                        .fixedSize()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(badgeBg, in: RoundedRectangle(cornerRadius: 3))
                        .padding(.leading, 4)
                } else if theme == .platformPulse {
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                        .padding(.leading, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func themePreviewRow() -> some View {
        let theme = hasPremiumAccess ? (RowTheme(rawValue: rowThemeRaw) ?? .none) : .none
        let vibrancy = hasPremiumAccess ? (ColourVibrancy(rawValue: colourVibrancyRaw) ?? .vibrant) : .vibrant
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if themePreviewIsLoading {
                    ProgressView().scaleEffect(0.75)
                } else {
                    Button {
                        Task { await fetchRandomThemePreview() }
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .font(.caption)
                    }
                    .foregroundStyle(Theme.brand)
                    .disabled(viewModel.stations.isEmpty)
                }
            }
            if let service = themePreviewService {
                let colours = OperatorColours.entry(for: service.operatorCode)
                DepartureRow(
                    service: service,
                    boardType: .departures,
                    rowTheme: theme,
                    colourVibrancy: vibrancy,
                    operatorColours: colours
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background { themePreviewBackground(theme: theme, vibrancy: vibrancy, colours: colours) }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(service.operator)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if !themePreviewIsLoading {
                Text("No preview available — check your connection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            if themePreviewService == nil {
                await fetchRandomThemePreview()
            }
        }
    }

    @ViewBuilder
    private func themePreviewBackground(theme: RowTheme, vibrancy: ColourVibrancy, colours: OperatorColours.Entry) -> some View {
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

    private func fetchRandomThemePreview() async {
        themePreviewIsLoading = true
        defer { themePreviewIsLoading = false }
        let stations = viewModel.stations
        guard !stations.isEmpty else { return }
        for _ in 0..<6 {
            guard let station = stations.randomElement() else { continue }
            guard let board = try? await StationViewModel.fetchBoard(for: station.crsCode, numRows: 5) else { continue }
            let services = (board.trainServices ?? []).filter { $0.operatorCode != "ZZ" }
            if let service = services.randomElement() {
                themePreviewService = service
                return
            }
        }
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
            guard requirePremium(.all) else { return }
            if let u = URL(string: url) { UIApplication.shared.open(u) }
        }
        .contextMenu {
            Button { UIPasteboard.general.string = url } label: {
                Label("Copy URL", systemImage: "doc.on.doc")
            }
            Button {
                guard requirePremium(.all) else { return }
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
                guard requirePremium(.serviceDetail) else { return }
                if let u = URL(string: url) { UIApplication.shared.open(u) }
            }
            .contextMenu {
                Button { UIPasteboard.general.string = url } label: {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }
                Button {
                    guard requirePremium(.serviceDetail) else { return }
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

// MARK: - Trial banner

private struct TrialBannerSection: View {
    let daysRemaining: Int
    let isExpired: Bool
    let hasSubscription: Bool

    @State private var showSubscribe = false
    private var isUrgent: Bool { daysRemaining <= 7 }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Header row
                HStack(spacing: 10) {
                    Image(systemName: hasSubscription ? "checkmark.seal.fill" : (isExpired ? "lock.fill" : "clock.fill"))
                        .font(.title2)
                        .foregroundStyle(hasSubscription ? .green : (isExpired ? .red : (isUrgent ? .orange : Theme.brand)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(hasSubscription ? "Departure Board Pro Active" : (isExpired ? "Trial Ended" : "Free Trial"))
                            .font(.headline)
                        Text(hasSubscription
                             ? "You're a Pro member. Thanks for supporting Departure Board."
                             : (isExpired
                                 ? "Your 28-day trial has expired."
                                 : (daysRemaining == 1
                                     ? "1 day remaining"
                                     : "\(daysRemaining) days remaining")))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Progress bar (only while trial is active)
                if !isExpired && !hasSubscription {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemFill))
                                .frame(height: 6)
                            Capsule()
                                .fill(isUrgent ? Color.orange : Theme.brand)
                                .frame(width: geo.size.width * CGFloat(daysRemaining) / CGFloat(TrialManager.trialDays), height: 6)
                        }
                    }
                    .frame(height: 6)
                }

                // Body copy
                Text(hasSubscription
                     ? "All Pro features are active, including widgets, themes, travel mode, and service details."
                     : (isExpired
                         ? "Subscribe to keep using widgets, themes, travel mode, coach details, and more."
                         : "Enjoying Departure Board? Subscribe to Departure Board Pro for widgets, themes, travel mode, coach details, and more — and keep everything working after your trial ends."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // CTA button
                if !hasSubscription {
                    Button {
                        showSubscribe = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(isExpired ? "Subscribe to Continue" : "Get Departure Board Pro")
                                .font(.subheadline.bold())
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .background(isExpired ? Color.red : Theme.brand, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text(hasSubscription ? "Unlocked" : (isExpired ? "Departure Board Pro Required" : "Your Trial"))
        }
        .sheet(isPresented: $showSubscribe) {
            SubscribeView()
        }
    }
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

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ReleaseCardShareView: View {
    private struct Highlight: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let highlights: [Highlight] = [
        .init(icon: "tram.fill", title: "Live UK Rail Boards", detail: "2,500+ stations • departures & arrivals in seconds"),
        .init(icon: "star.fill", title: "Smarter Favourites", detail: "Saved boards, recent filters, and next-service glance cards"),
        .init(icon: "rectangle.3.group.fill", title: "Widgets + Lock Screen", detail: "Single and dual boards with quick tap-through"),
        .init(icon: "info.circle.fill", title: "Deep Service & Station Info", detail: "Calling points, platforms, facilities, and disruption context")
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 11/255, green: 16/255, blue: 29/255),
                    Color(red: 14/255, green: 42/255, blue: 56/255),
                    Color(red: 8/255, green: 11/255, blue: 18/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("DEPARTURE BOARD")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Version 1.0")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.brand)
                    Text("Built to get you to your train, faster.")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }

                HStack(spacing: 14) {
                    statPill(value: "60s", label: "Live Refresh")
                    statPill(value: "5m", label: "Widget Updates")
                    statPill(value: "28d", label: "Free Trial")
                }

                VStack(spacing: 12) {
                    ForEach(highlights) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Theme.brand)
                                .frame(width: 30, height: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(item.detail)
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.82))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(24)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                }

                Spacer(minLength: 0)

                HStack {
                    Label("Made by Daniel Breslan", systemImage: "sparkles")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Text("Launch Build · 2026")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(56)
        }
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.brand.opacity(0.20), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.brand.opacity(0.45), lineWidth: 1)
        }
    }
}
