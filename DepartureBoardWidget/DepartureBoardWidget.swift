//
//  DepartureBoardWidget.swift
//  DepartureBoardWidget
//
//  Created by Daniel Breslan on 16/02/2026.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Intents for Configuration

/// Sentinel CRS used to mean "resolve to nearest station at fetch time".
private let nearestStationCRS = "__nearest__"

struct BoardQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [BoardEntity] {
        // Return the nearest sentinel entity without resolving — the provider resolves it at fetch time.
        let stations = loadStationCache()
        return identifiers.compactMap { id in
            if id.hasPrefix(nearestStationCRS) {
                let boardType: BoardType = id.hasSuffix("arr") ? .arrivals : .departures
                return nearestStationEntity(boardType: boardType)
            }
            return boardEntity(for: id, stations: stations)
        }
    }

    func suggestedEntities() async throws -> [BoardEntity] {
        let stations = loadStationCache()
        let favItems = loadFavouriteBoards()

        // "Nearest Station" at the top
        var results: [BoardEntity] = [
            nearestStationEntity(boardType: .departures),
            nearestStationEntity(boardType: .arrivals),
        ]

        // Favourites next
        for itemID in favItems {
            if let entity = boardEntity(for: itemID, stations: stations) {
                results.append(entity)
            }
        }

        // Then all stations as departures (excluding already-added)
        let addedIDs = Set(results.map(\.id))
        for station in stations {
            let depID = SharedDefaults.boardID(crs: station.crsCode, boardType: .departures)
            if !addedIDs.contains(depID) {
                results.append(BoardEntity(
                    id: depID,
                    displayName: station.name,
                    subtitle: "Departures",
                    crs: station.crsCode,
                    boardType: .departures,
                    filterCrs: nil,
                    filterType: nil
                ))
            }
        }

        return results
    }

    private func nearestStationEntity(boardType: BoardType) -> BoardEntity {
        let suffix = boardType == .departures ? "dep" : "arr"
        return BoardEntity(
            id: "\(nearestStationCRS)-\(suffix)",
            displayName: "Nearest Station",
            subtitle: boardType == .departures ? "Departures · Auto" : "Arrivals · Auto",
            crs: nearestStationCRS,
            boardType: boardType,
            filterCrs: nil,
            filterType: nil
        )
    }

    func defaultResult() async -> BoardEntity? {
        let favItems = loadFavouriteBoards()
        let stations = loadStationCache()
        guard let firstID = favItems.first else { return nil }
        return boardEntity(for: firstID, stations: stations)
    }

    private func boardEntity(for id: String, stations: [Station]) -> BoardEntity? {
        guard let parsed = SharedDefaults.parseBoardID(id),
              let station = stations.first(where: { $0.crsCode == parsed.crs }) else { return nil }
        if let filterCrs = parsed.filterCrs, let filterType = parsed.filterType {
            let filterStation = stations.first(where: { $0.crsCode == filterCrs })
            let filterLabel = filterType == "to"
                ? "Calling at \(filterStation?.name ?? filterCrs)"
                : "From \(filterStation?.name ?? filterCrs)"
            return BoardEntity(
                id: id,
                displayName: station.name,
                subtitle: "\(parsed.boardType.rawValue.capitalized) · \(filterLabel)",
                crs: parsed.crs,
                boardType: parsed.boardType,
                filterCrs: filterCrs,
                filterType: filterType
            )
        }
        return BoardEntity(
            id: id,
            displayName: station.name,
            subtitle: parsed.boardType.rawValue.capitalized,
            crs: parsed.crs,
            boardType: parsed.boardType,
            filterCrs: nil,
            filterType: nil
        )
    }
}

struct BoardEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Board")
    static var defaultQuery = BoardQuery()

    let id: String
    let displayName: String
    let subtitle: String
    let crs: String
    let boardType: BoardType
    let filterCrs: String?
    let filterType: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(subtitle)")
    }
}

struct SingleStationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Station Board"
    static var description: IntentDescription = "Shows departures or arrivals from a station, optionally filtered."

    @Parameter(title: "Board")
    var board: BoardEntity?
}

struct DualStationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Two Station Boards"
    static var description: IntentDescription = "Shows boards from two stations."

    @Parameter(title: "First Board")
    var firstBoard: BoardEntity?

    @Parameter(title: "Second Board")
    var secondBoard: BoardEntity?
}

struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Widget"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Timeline Entry

struct DepartureEntry: TimelineEntry {
    let date: Date
    let stations: [StationDepartures]
    var isOutsideUK: Bool = false
    var londonTimeString: String = ""

    struct StationDepartures {
        let name: String
        let crs: String
        let filterLabel: String?
        let filterCrs: String?
        let filterType: String?
        let services: [WidgetService]
        var errorMessage: String? = nil
        var error: Bool { errorMessage != nil }
    }

    struct WidgetService: Identifiable {
        let id: String
        let scheduled: String
        let destination: String
        let platform: String?
        let status: String
        let isCancelled: Bool
        let isDelayed: Bool
        let isBus: Bool
        let operatorCode: String
    }
}

// MARK: - Single Station Provider

struct SingleStationProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DepartureEntry {
        .mock(stationCount: 1, serviceCount: 16)
    }

    func snapshot(for configuration: SingleStationIntent, in context: Context) async -> DepartureEntry {
        if context.isPreview {
            return .mock(stationCount: 1, serviceCount: 16)
        }
        return await fetchEntry(boards: selectedBoards(for: configuration), servicesPerStation: 16)
    }

    func timeline(for configuration: SingleStationIntent, in context: Context) async -> Timeline<DepartureEntry> {
        if let loc = loadLastKnownLocation(), !isInUK(lat: loc.lat, lon: loc.lon) {
            return travelTimeline()
        }
        let entry = await fetchEntry(boards: selectedBoards(for: configuration), servicesPerStation: 16)
        let nextRefresh = Date().addingTimeInterval(300)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func selectedBoards(for config: SingleStationIntent) -> [BoardConfig] {
        if let board = config.board {
            let raw = BoardConfig(crs: board.crs, boardType: board.boardType, filterCrs: board.filterCrs, filterType: board.filterType)
            return [resolveBoard(raw)]
        }
        // Fall back to first favourite
        return defaultBoards(count: 1)
    }
}

// MARK: - Dual Station Provider

struct DualStationProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DepartureEntry {
        .mock(stationCount: 2, serviceCount: 8)
    }

    func snapshot(for configuration: DualStationIntent, in context: Context) async -> DepartureEntry {
        if context.isPreview {
            return .mock(stationCount: 2, serviceCount: 8)
        }
        return await fetchEntry(boards: selectedBoards(for: configuration), servicesPerStation: 8)
    }

    func timeline(for configuration: DualStationIntent, in context: Context) async -> Timeline<DepartureEntry> {
        if let loc = loadLastKnownLocation(), !isInUK(lat: loc.lat, lon: loc.lon) {
            return travelTimeline()
        }
        let entry = await fetchEntry(boards: selectedBoards(for: configuration), servicesPerStation: 8)
        let nextRefresh = Date().addingTimeInterval(300)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func selectedBoards(for config: DualStationIntent) -> [BoardConfig] {
        var boards: [BoardConfig] = []
        if let b = config.firstBoard {
            boards.append(resolveBoard(BoardConfig(crs: b.crs, boardType: b.boardType, filterCrs: b.filterCrs, filterType: b.filterType)))
        }
        if let b = config.secondBoard {
            boards.append(resolveBoard(BoardConfig(crs: b.crs, boardType: b.boardType, filterCrs: b.filterCrs, filterType: b.filterType)))
        }
        if boards.isEmpty {
            boards = defaultBoards(count: 2)
        }
        return boards
    }
}

// MARK: - Shared Fetch Logic

struct BoardConfig {
    let crs: String
    let boardType: BoardType
    let filterCrs: String?
    let filterType: String?
}

/// Resolves the `__nearest__` sentinel to the actual nearest station CRS, if location is available.
private func resolveNearestCRS() -> String? {
    guard let loc = loadLastKnownLocation() else { return nil }
    let stations = loadStationCache()
    return stations.min(by: { s0, s1 in
        let d0 = (s0.latitude - loc.lat) * (s0.latitude - loc.lat) + (s0.longitude - loc.lon) * (s0.longitude - loc.lon)
        let d1 = (s1.latitude - loc.lat) * (s1.latitude - loc.lat) + (s1.longitude - loc.lon) * (s1.longitude - loc.lon)
        return d0 < d1
    })?.crsCode
}

private func resolveBoard(_ config: BoardConfig) -> BoardConfig {
    guard config.crs == nearestStationCRS else { return config }
    let crs = resolveNearestCRS() ?? config.crs   // fall back to sentinel (will show error gracefully)
    return BoardConfig(crs: crs, boardType: config.boardType, filterCrs: nil, filterType: nil)
}

private func defaultBoards(count: Int) -> [BoardConfig] {
    let favItems = loadFavouriteBoards()
    let stations = loadStationCache()

    var boards: [BoardConfig] = []
    for itemID in favItems {
        if boards.count >= count { break }
        if let parsed = SharedDefaults.parseBoardID(itemID),
           stations.contains(where: { $0.crsCode == parsed.crs }) {
            boards.append(BoardConfig(crs: parsed.crs, boardType: parsed.boardType, filterCrs: parsed.filterCrs, filterType: parsed.filterType))
        }
    }
    return boards
}

private func fetchEntry(boards: [BoardConfig], servicesPerStation: Int) async -> DepartureEntry {
    let stations = loadStationCache()
    var stationDepartures: [DepartureEntry.StationDepartures] = []

    for board in boards {
        let name = stations.first(where: { $0.crsCode == board.crs })?.name ?? board.crs
        let filterLabel: String? = {
            guard let filterCrs = board.filterCrs, let filterType = board.filterType else { return nil }
            let filterName = stations.first(where: { $0.crsCode == filterCrs })?.name ?? filterCrs
            return filterType == "to" ? "Calling at \(filterName)" : "From \(filterName)"
        }()
        do {
            let result = try await fetchBoard(crs: board.crs, boardType: board.boardType, numRows: servicesPerStation, filterCrs: board.filterCrs, filterType: board.filterType)
            let combined = (result.trainServices ?? []) + (result.busServices ?? [])
            let allServices = combined.enumerated().sorted { lhs, rhs in
                // Sort HH:mm strings with overnight wraparound:
                // times before 06:00 are treated as next-day (add 24h) so they
                // sort after late-night services like 23:xx.
                // Non-time values (e.g. "Delayed") keep their original position.
                func sortKey(_ t: String) -> Int? {
                    let parts = t.split(separator: ":").compactMap { Int($0) }
                    guard parts.count == 2 else { return nil }
                    let mins = parts[0] * 60 + parts[1]
                    return mins < 360 ? mins + 1440 : mins
                }
                let isDep = board.boardType != .arrivals
                let aTime = isDep ? (lhs.element.std ?? lhs.element.sta) : (lhs.element.sta ?? lhs.element.std)
                let bTime = isDep ? (rhs.element.std ?? rhs.element.sta) : (rhs.element.sta ?? rhs.element.std)
                let ak = sortKey(aTime ?? "")
                let bk = sortKey(bTime ?? "")
                switch (ak, bk) {
                case let (a?, b?): return a < b
                default: return lhs.offset < rhs.offset
                }
            }.map(\.element)
            let services = allServices.prefix(servicesPerStation).map { service in
                let dest = service.destination.map(\.locationName).joined(separator: " & ")
                let status = service.estimated
                let isCancelled = service.isCancelled
                // Use departure time for departures boards, arrival time for arrivals boards
                let scheduledTime = board.boardType == .arrivals
                    ? (service.sta ?? service.std ?? "missing")
                    : (service.std ?? service.sta ?? "missing")
                let isDelayed = !isCancelled && (status.lowercased().contains("delayed") ||
                    (isTimeFormat(status) && status > scheduledTime))
                return DepartureEntry.WidgetService(
                    id: service.serviceId,
                    scheduled: scheduledTime,
                    destination: dest,
                    platform: service.platform,
                    status: status,
                    isCancelled: isCancelled,
                    isDelayed: isDelayed,
                    isBus: service.serviceType == "bus",
                    operatorCode: service.operatorCode
                )
            }
            stationDepartures.append(.init(name: name, crs: board.crs, filterLabel: filterLabel, filterCrs: board.filterCrs, filterType: board.filterType, services: Array(services)))
        } catch {
            let message = widgetErrorMessages.randomElement()!
            stationDepartures.append(.init(name: name, crs: board.crs, filterLabel: filterLabel, filterCrs: board.filterCrs, filterType: board.filterType, services: [], errorMessage: message))
        }
    }

    return DepartureEntry(date: Date(), stations: stationDepartures)
}

private func loadFavouriteBoards() -> [String] {
    guard let data = SharedDefaults.shared.data(forKey: SharedDefaults.Keys.favouriteBoards) else { return [] }
    return (try? JSONDecoder().decode([String].self, from: data)) ?? []
}

private func loadStationCache() -> [Station] {
    guard let data = SharedDefaults.shared.data(forKey: SharedDefaults.Keys.cachedStations) else { return [] }
    return (try? JSONDecoder().decode([Station].self, from: data)) ?? []
}

private func fetchBoard(crs: String, boardType: BoardType, numRows: Int, filterCrs: String? = nil, filterType: String? = nil) async throws -> DepartureBoard {
    var components = URLComponents(string: "\(APIConfig.baseURL)/\(boardType.rawValue)/\(crs)")!
    var queryItems = [URLQueryItem(name: "numRows", value: String(numRows))]
    if let filterCrs { queryItems.append(URLQueryItem(name: "filterCrs", value: filterCrs)) }
    if let filterType { queryItems.append(URLQueryItem(name: "filterType", value: filterType)) }
    components.queryItems = queryItems
    let (data, response) = try await URLSession.shared.data(from: components.url!)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw URLError(.badServerResponse)
    }
    return try JSONDecoder().decode(DepartureBoard.self, from: data)
}

// MARK: - Location / UK Detection

private func loadLastKnownLocation() -> (lat: Double, lon: Double)? {
    guard SharedDefaults.shared.object(forKey: SharedDefaults.Keys.lastKnownLatitude) != nil else { return nil }
    let lat = SharedDefaults.shared.double(forKey: SharedDefaults.Keys.lastKnownLatitude)
    let lon = SharedDefaults.shared.double(forKey: SharedDefaults.Keys.lastKnownLongitude)
    return (lat, lon)
}

private func isInUK(lat: Double, lon: Double) -> Bool {
    lat >= 49.9 && lat <= 60.9 && lon >= -8.2 && lon <= 1.8
}

private func formatLondonTime(_ date: Date) -> String {
    let fmt = DateFormatter()
    fmt.timeZone = TimeZone(identifier: "Europe/London")
    fmt.dateFormat = "HH:mm"
    return fmt.string(from: date)
}

/// Generates per-minute entries for the next hour so the London clock ticks live.
private func travelTimeline() -> Timeline<DepartureEntry> {
    let now = Date()
    let entries = (0..<60).map { minute -> DepartureEntry in
        let d = now.addingTimeInterval(Double(minute) * 60)
        return DepartureEntry(date: d, stations: [], isOutsideUK: true, londonTimeString: formatLondonTime(d))
    }
    return Timeline(entries: entries, policy: .atEnd)
}

private let widgetErrorMessages = [
    "Delayed by a network error.",
    "Signal failure. Data couldn't get through.",
    "Leaves on the line. Or a network error.",
    "This service has been cancelled.",
    "Currently held at a red light.",
]

private func isTimeFormat(_ text: String) -> Bool {
    text.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil
}

// MARK: - Mock Data

extension DepartureEntry {
    static func mock(stationCount: Int, serviceCount: Int) -> DepartureEntry {
        let mockServices = (0..<serviceCount).map { i in
            WidgetService(
                id: "mock-\(i)",
                scheduled: String(format: "%02d:%02d", 8 + i / 4, (i * 15) % 60),
                destination: ["London Paddington", "Bristol Temple Meads", "Cardiff Central", "Birmingham New St", "Manchester Picc.", "Edinburgh Waverley"][i % 6],
                platform: "\(i + 1)",
                status: i == 0 ? "On time" : String(format: "%02d:%02d", 8 + i / 4, ((i * 15) + 3) % 60),
                isCancelled: false,
                isDelayed: i > 0,
                isBus: false,
                operatorCode: ["GW", "TP", "SR", "VT", "GR", "SW"][i % 6]
            )
        }
        let stations = (0..<stationCount).map { i in
            StationDepartures(
                name: ["London Waterloo", "Clapham Junction"][i % 2],
                crs: ["WAT", "CLJ"][i % 2],
                filterLabel: nil,
                filterCrs: nil,
                filterType: nil,
                services: mockServices
            )
        }
        return DepartureEntry(date: Date(), stations: stations)
    }
}

// MARK: - Widget Views

struct SingleStationWidgetView: View {
    let entry: DepartureEntry
    @Environment(\.widgetFamily) var family

    private var maxRows: Int {
        switch family {
        case .systemSmall: return 7
        case .systemMedium: return 7
        default: return 16
        }
    }

    private var rowStyle: WidgetRowStyle {
        switch family {
        case .systemSmall: return .minimal
        case .systemMedium: return .compact
        default: return .full
        }
    }

    var body: some View {
        if entry.isOutsideUK {
            TravelView(londonTime: entry.londonTimeString, entryDate: entry.date)
        } else if let station = entry.stations.first {
            StationBlock(station: station, entryDate: entry.date, style: rowStyle, maxRows: maxRows)
        } else {
            Text("Tap and hold to choose a station")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct DualStationWidgetView: View {
    let entry: DepartureEntry
    @Environment(\.widgetFamily) var family

    private var maxRowsPerStation: Int {
        family == .systemMedium ? 3 : 8
    }

    var body: some View {
        if entry.isOutsideUK {
            TravelView(londonTime: entry.londonTimeString, entryDate: entry.date)
        } else if entry.stations.isEmpty {
            Text("Tap and hold to choose stations")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 0) {
                if let first = entry.stations.first {
                    StationBlock(station: first, entryDate: entry.date, style: .compact, maxRows: maxRowsPerStation)
                }
                if entry.stations.count > 1 {
                    Divider()
                        .padding(.horizontal)
                    StationBlock(station: entry.stations[1], entryDate: entry.date, style: .compact, maxRows: maxRowsPerStation)
                }
            }
        }
    }
}

struct LockScreenBoardWidgetView: View {
    let entry: DepartureEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if entry.isOutsideUK {
            lockScreenFallback("Abroad")
        } else if let station = entry.stations.first {
            switch family {
            case .accessoryInline:
                InlineBoardView(station: station)
            case .accessoryCircular:
                CircularBoardView(station: station)
            case .accessoryRectangular:
                RectangularBoardView(station: station)
            default:
                lockScreenFallback("Board")
            }
        } else {
            lockScreenFallback("Set station")
        }
    }

    @ViewBuilder
    private func lockScreenFallback(_ text: String) -> some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "train.side.front.car")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .widgetLabel(text)
        default:
            Text(text)
        }
    }
}

private struct InlineBoardView: View {
    let station: DepartureEntry.StationDepartures

    var body: some View {
        if let service = station.services.first {
            Text("\(service.scheduled) \(destinationArrow(service.destination)) \(statusText(for: service))")
                .lineLimit(1)
        } else if station.error {
            Text("Board unavailable")
        } else {
            Text("No departures soon")
        }
    }
}

private struct CircularBoardView: View {
    let station: DepartureEntry.StationDepartures

    var body: some View {
        if let service = station.services.first {
            ZStack {
                AccessoryWidgetBackground()
                Text(service.scheduled)
                    .font(.system(.caption2, design: .monospaced).bold())
                    .minimumScaleFactor(0.7)
            }
            .widgetLabel(circularStatus(for: service))
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: station.error ? "exclamationmark.triangle" : "minus")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .widgetLabel(station.error ? "Board unavailable" : "No departures")
        }
    }
}

private struct RectangularBoardView: View {
    let station: DepartureEntry.StationDepartures

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(station.name)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)

            if station.error {
                Text("Board unavailable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if station.services.isEmpty {
                Text("No departures soon")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(station.services.prefix(2))) { service in
                    HStack(spacing: 4) {
                        Text(service.scheduled)
                            .font(.system(.caption2, design: .monospaced).weight(.semibold))
                            .fixedSize()
                        Text(service.destination)
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text(compactStatus(for: service))
                            .font(.caption2)
                            .foregroundStyle(statusColor(for: service))
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

private func destinationArrow(_ destination: String) -> String {
    "→ \(destination)"
}

private func statusText(for service: DepartureEntry.WidgetService) -> String {
    if service.isCancelled { return "Cancelled" }
    if service.isDelayed { return delayedStatus(for: service) }
    return "On time"
}

private func delayedStatus(for service: DepartureEntry.WidgetService) -> String {
    guard let delayMinutes = delayMinutes(for: service), delayMinutes > 0 else {
        return "Delayed"
    }
    return "+\(delayMinutes)m"
}

private func compactStatus(for service: DepartureEntry.WidgetService) -> String {
    if service.isCancelled { return "Canx" }
    if service.isDelayed { return delayedStatus(for: service) }
    return "On time"
}

private func circularStatus(for service: DepartureEntry.WidgetService) -> String {
    if service.isCancelled { return "Canx" }
    if service.isDelayed { return delayedStatus(for: service) }
    return "On time"
}

private func statusColor(for service: DepartureEntry.WidgetService) -> Color {
    if service.isCancelled { return .red }
    if service.isDelayed { return .orange }
    return .secondary
}

private func delayMinutes(for service: DepartureEntry.WidgetService) -> Int? {
    guard isTimeFormat(service.status),
          isTimeFormat(service.scheduled) else { return nil }
    func minutes(from text: String) -> Int? {
        let parts = text.split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let mins = Int(parts[1]) else { return nil }
        return hours * 60 + mins
    }
    guard let statusMinutes = minutes(from: service.status),
          let scheduledMinutes = minutes(from: service.scheduled) else { return nil }
    var delta = statusMinutes - scheduledMinutes
    if delta < 0 { delta += 24 * 60 }
    return delta
}

enum WidgetRowStyle {
    case minimal  // small widget: no status text, colour the time instead
    case compact  // medium / dual: compact with status
    case full     // large: full size with status
}

/// Widget-specific row themes, stored in SharedDefaults so the widget can read them.
/// Uses the app's brand colour as the accent rather than per-operator colours.
enum WidgetTheme: String {
    case none          = "none"
    case trackline     = "trackline"
    case signalRail    = "signalRail"
    case timeTile      = "timeTile"
    case platformPulse = "platformPulse"
}

private func loadWidgetTheme() -> WidgetTheme {
    let raw = SharedDefaults.shared.string(forKey: SharedDefaults.Keys.widgetRowTheme) ?? "none"
    return WidgetTheme(rawValue: raw) ?? .none
}

private func loadWidgetColourMode() -> String {
    SharedDefaults.shared.string(forKey: SharedDefaults.Keys.widgetColourMode) ?? "brand"
}

private func loadWidgetSplitFlap() -> Bool {
    SharedDefaults.shared.bool(forKey: SharedDefaults.Keys.widgetSplitFlap)
}

private func widgetAccentColor(for code: String) -> (color: Color, isLight: Bool) {
    let table: [String: (String, Bool)] = [
        "AW": ("#00A3A6", false), "CC": ("#B81C8D", false), "CH": ("#000080", false),
        "EM": ("#582C83", false), "ES": ("#0C1C8C", false), "GM": ("#003057", false),
        "GN": ("#1D2D5C", false), "GR": ("#CF0A2C", false), "GW": ("#0B2D27", false),
        "GX": ("#CF0A2C", false), "HS": ("#1D2D5C", false), "HV": ("#003057", false),
        "HX": ("#4B006E", false), "IL": ("#1E90FF", false), "LE": ("#CC0000", false),
        "LN": ("#004CA4", false), "LO": ("#EE7C0E", false), "LT": ("#E32017", false),
        "ME": ("#FFF200", true),  "NR": ("#003057", false), "NT": ("#23335F", false),
        "SE": ("#1D2D5C", false), "SN": ("#8CC63E", false), "SR": ("#003D8F", false),
        "SW": ("#1D2D5C", false), "TL": ("#E6007E", false), "TP": ("#010385", false),
        "VT": ("#004C45", false), "WM": ("#7B2082", false), "XP": ("#010385", false),
        "XR": ("#6950A1", false), "XS": ("#003D8F", false), "ZZ": ("#8E8E93", false),
    ]
    let (hex, isLight) = table[code] ?? table["ZZ"]!
    let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0; Scanner(string: h).scanHexInt64(&int)
    let color = Color(red: Double((int >> 16) & 0xFF) / 255,
                      green: Double((int >> 8)  & 0xFF) / 255,
                      blue:  Double(int         & 0xFF) / 255)
    return (color, isLight)
}

struct StationBlock: View {
    let station: DepartureEntry.StationDepartures
    let entryDate: Date
    var style: WidgetRowStyle = .full
    var maxRows: Int? = nil

    var body: some View {
        let services = maxRows.map { Array(station.services.prefix($0)) } ?? station.services
        VStack(alignment: .leading, spacing: style == .full ? 4 : 2) {
            let arrow = station.filterType == "from" ? "←" : "→"
            let filterText: String? = {
                guard let crs = station.filterCrs else { return nil }
                if style == .minimal {
                    return "\(arrow) \(crs)"
                }
                if let label = station.filterLabel {
                    if label.hasPrefix("Calling at ") {
                        return "→ \(label.dropFirst("Calling at ".count))"
                    } else if label.hasPrefix("From ") {
                        return "← \(label.dropFirst("From ".count))"
                    }
                }
                return "\(arrow) \(crs)"
            }()
            HStack(alignment: .center, spacing: 4) {
                Link(destination: URL(string: "departure://departures/\(station.crs)")!) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(station.name)
                            .font({
                                let sc = UserDefaults.standard.bool(forKey: "stationNamesSmallCaps")
                                return Font.caption.weight(.bold).smallCapsIfEnabled(sc)
                            }())
                            .foregroundStyle(Theme.brand)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        if let filterText {
                            Text(filterText)
                                .font(.system(size: 9).weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
                if style != .minimal {
                    Text(entryDate, style: .relative)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                Button(intent: RefreshWidgetIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: style == .minimal ? 9 : 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if let message = station.errorMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if station.services.isEmpty {
                Text("No services")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let splitFlap = loadWidgetSplitFlap()
                ForEach(services) { service in
                    let encodedID = service.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? service.id
                    Link(destination: URL(string: "departure://service/\(station.crs)/\(encodedID)")!) {
                        WidgetDepartureRow(service: service, style: style)
                    }
                    .transition(splitFlap
                        ? .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .move(edge: .top).combined(with: .opacity))
                        : .identity)
                }
                .animation(.easeInOut(duration: 0.3), value: services.map(\.id))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WidgetDepartureRow: View {
    let service: DepartureEntry.WidgetService
    var style: WidgetRowStyle = .full
    @Environment(\.colorScheme) private var colorScheme

    private var theme: WidgetTheme { loadWidgetTheme() }
    private var isCompact: Bool { style != .full }

    private var accentColor: Color {
        loadWidgetColourMode() == "operator"
            ? widgetAccentColor(for: service.operatorCode).color
            : Theme.brand
    }
    private var accentIsLight: Bool {
        loadWidgetColourMode() == "operator" && widgetAccentColor(for: service.operatorCode).isLight
    }

    private var statusColor: Color {
        if service.isCancelled { return .red }
        if service.isDelayed { return .orange }
        return .primary
    }

    private var timeForeground: Color {
        if style == .minimal { return statusColor }
        if theme == .timeTile { return accentIsLight ? .black : .white }
        return .primary
    }

    var body: some View {
        HStack(spacing: 0) {
            // MARK: Trackline accent stripe
            if theme == .trackline {
                accentColor
                    .frame(width: 2)
                    .padding(.vertical, isCompact ? 1 : 2)
                    .padding(.trailing, 5)
            }

            // MARK: Time
            let timeText = Text(service.scheduled)
                .font(.system(isCompact ? .caption2 : .caption, design: .monospaced).bold())
                .foregroundStyle(timeForeground)
                .lineLimit(1)
                .fixedSize()
                .contentTransition(.numericText())

            if theme == .timeTile {
                timeText
                    .padding(.vertical, isCompact ? 1 : 2)
                    .padding(.horizontal, isCompact ? 3 : 4)
                    .background(accentColor, in: RoundedRectangle(cornerRadius: 3))
                    .padding(.trailing, 5)
            } else {
                timeText
                    .frame(width: isCompact ? 36 : 40, alignment: .leading)
            }

            // MARK: Signal Rail divider
            if theme == .signalRail {
                accentColor
                    .frame(width: 1.5)
                    .padding(.vertical, isCompact ? 1 : 2)
                    .padding(.horizontal, 4)
            }

            // MARK: Destination
            Text(service.destination)
                .font(isCompact ? .caption2 : .caption)
                .lineLimit(1)
                .contentTransition(.interpolate)

            Spacer(minLength: 0)

            // MARK: Status / cancelled
            if style == .minimal {
                if service.isCancelled {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            } else {
                if service.isCancelled {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else if service.status.lowercased() != "on time" {
                    Text(service.status)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(service.isDelayed ? .orange : .secondary)
                        .contentTransition(.numericText())
                }
            }

            if service.isBus {
                Image(systemName: "bus.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }

            // MARK: Platform badge
            if let platform = service.platform {
                let badgeBg: Color = theme == .platformPulse
                    ? accentColor
                    : (colorScheme == .dark ? Theme.platformBadgeDark : Theme.platformBadge)
                let badgeFg: Color = theme == .platformPulse
                    ? (accentIsLight ? Color.black : Color.white)
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
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                    .padding(.leading, 4)
            }
        }
    }
}

// MARK: - Travel View (outside UK)

struct TravelView: View {
    let londonTime: String
    let entryDate: Date
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("🌍 Abroad")
                    .font(.caption.bold())
                Spacer(minLength: 0)
                Button(intent: RefreshWidgetIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 1) {
                Text("London")
                    .font(.system(size: family == .systemSmall ? 10 : 11).weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(londonTime)
                    .font(.system(family == .systemSmall ? .title : .largeTitle, design: .monospaced).bold())
                    .foregroundStyle(Theme.brand)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if family != .systemSmall {
                Text("See you back on the rails! 🚂")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Widget Definitions

struct SingleStationWidget: Widget {
    let kind = "SingleStationWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SingleStationIntent.self, provider: SingleStationProvider()) { entry in
            SingleStationWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Station Board")
        .description("Departures or arrivals from a station, with optional filter.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .promptsForUserConfiguration()
    }
}

struct DualStationWidget: Widget {
    let kind = "DualStationWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: DualStationIntent.self, provider: DualStationProvider()) { entry in
            DualStationWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Two Boards")
        .description("Boards from two chosen stations.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .promptsForUserConfiguration()
    }
}

struct LockScreenBoardWidget: Widget {
    let kind = "LockScreenBoardWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SingleStationIntent.self, provider: SingleStationProvider()) { entry in
            LockScreenBoardWidgetView(entry: entry)
                .widgetURL(lockScreenBoardURL(from: entry))
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Board Next Train")
        .description("Next departures for your station on the Lock Screen.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private func lockScreenBoardURL(from entry: DepartureEntry) -> URL? {
    guard let station = entry.stations.first else { return nil }
    return URL(string: "departure://departures/\(station.crs)")
}

