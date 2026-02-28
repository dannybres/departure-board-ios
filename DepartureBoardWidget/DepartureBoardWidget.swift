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

struct BoardQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [BoardEntity] {
        let stations = loadStationCache()
        return identifiers.compactMap { id in
            boardEntity(for: id, stations: stations)
        }
    }

    func suggestedEntities() async throws -> [BoardEntity] {
        let stations = loadStationCache()
        let favItems = loadFavouriteBoards()

        // Build entities from favourite items first
        var results: [BoardEntity] = []
        for itemID in favItems {
            if let entity = boardEntity(for: itemID, stations: stations) {
                results.append(entity)
            }
        }

        // Then add all stations as departures (excluding already-added)
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

// MARK: - Timeline Entry

struct DepartureEntry: TimelineEntry {
    let date: Date
    let stations: [StationDepartures]

    struct StationDepartures {
        let name: String
        let crs: String
        let filterLabel: String?
        let filterCrs: String?
        let filterType: String?
        let services: [WidgetService]
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
        let entry = await fetchEntry(boards: selectedBoards(for: configuration), servicesPerStation: 16)
        let nextRefresh = Date().addingTimeInterval(300)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func selectedBoards(for config: SingleStationIntent) -> [BoardConfig] {
        if let board = config.board {
            return [BoardConfig(crs: board.crs, boardType: board.boardType, filterCrs: board.filterCrs, filterType: board.filterType)]
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
        let entry = await fetchEntry(boards: selectedBoards(for: configuration), servicesPerStation: 8)
        let nextRefresh = Date().addingTimeInterval(300)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func selectedBoards(for config: DualStationIntent) -> [BoardConfig] {
        var boards: [BoardConfig] = []
        if let b = config.firstBoard {
            boards.append(BoardConfig(crs: b.crs, boardType: b.boardType, filterCrs: b.filterCrs, filterType: b.filterType))
        }
        if let b = config.secondBoard {
            boards.append(BoardConfig(crs: b.crs, boardType: b.boardType, filterCrs: b.filterCrs, filterType: b.filterType))
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
                    isBus: service.serviceType == "bus"
                )
            }
            stationDepartures.append(.init(name: name, crs: board.crs, filterLabel: filterLabel, filterCrs: board.filterCrs, filterType: board.filterType, services: Array(services)))
        } catch {
            stationDepartures.append(.init(name: name, crs: board.crs, filterLabel: filterLabel, filterCrs: board.filterCrs, filterType: board.filterType, services: []))
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
                isBus: false
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
        if let station = entry.stations.first {
            StationBlock(station: station, style: rowStyle, maxRows: maxRows)
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
        if entry.stations.isEmpty {
            Text("Tap and hold to choose stations")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 0) {
                if let first = entry.stations.first {
                    StationBlock(station: first, style: .compact, maxRows: maxRowsPerStation)
                }
                if entry.stations.count > 1 {
                    Divider()
                        .padding(.horizontal)
                    StationBlock(station: entry.stations[1], style: .compact, maxRows: maxRowsPerStation)
                }
            }
        }
    }
}

enum WidgetRowStyle {
    case minimal  // small widget: no status text, colour the time instead
    case compact  // medium / dual: compact with status
    case full     // large: full size with status
}

struct StationBlock: View {
    let station: DepartureEntry.StationDepartures
    var style: WidgetRowStyle = .full
    var maxRows: Int? = nil

    var body: some View {
        let services = maxRows.map { Array(station.services.prefix($0)) } ?? station.services
        VStack(alignment: .leading, spacing: style == .full ? 4 : 2) {
            Link(destination: URL(string: "departure://departures/\(station.crs)")!) {
                let arrow = station.filterType == "from" ? "←" : "→"
                let filterText: String? = {
                    guard let crs = station.filterCrs else { return nil }
                    if style == .minimal {
                        return "\(arrow) \(crs)"
                    }
                    // Derive "→ Station Name" from filterLabel ("Calling at Station Name" / "From Station Name")
                    if let label = station.filterLabel {
                        if label.hasPrefix("Calling at ") {
                            return "→ \(label.dropFirst("Calling at ".count))"
                        } else if label.hasPrefix("From ") {
                            return "← \(label.dropFirst("From ".count))"
                        }
                    }
                    return "\(arrow) \(crs)"
                }()
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

            if station.services.isEmpty {
                Text("No services")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(services) { service in
                    let encodedID = service.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? service.id
                    Link(destination: URL(string: "departure://service/\(station.crs)/\(encodedID)")!) {
                        WidgetDepartureRow(service: service, style: style)
                    }
                }
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

    private var timeColor: Color {
        if service.isCancelled { return .red }
        if service.isDelayed { return .orange }
        return .primary
    }

    private var isCompact: Bool { style != .full }

    var body: some View {
        HStack(spacing: 6) {
            Text(service.scheduled)
                .font(.system(isCompact ? .caption2 : .caption, design: .monospaced).bold())
                .foregroundStyle(style == .minimal ? timeColor : .primary)
                .frame(width: isCompact ? 36 : 40, alignment: .leading)

            Text(service.destination)
                .font(isCompact ? .caption2 : .caption)
                .lineLimit(1)

            Spacer(minLength: 0)

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
                }
            }

            if service.isBus {
                Image(systemName: "bus.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let platform = service.platform {
                Text(platform)
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                    .fixedSize()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        colorScheme == .dark ? Theme.platformBadgeDark : Theme.platformBadge,
                        in: RoundedRectangle(cornerRadius: 3)
                    )
            }
        }
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
    }
}
