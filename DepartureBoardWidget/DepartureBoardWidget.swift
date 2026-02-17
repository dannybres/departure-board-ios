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

struct StationQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [StationEntity] {
        let stations = loadStationCache()
        let favourites = loadFavourites()
        return identifiers.compactMap { crs in
            guard let station = stations.first(where: { $0.crsCode == crs }) else { return nil }
            return StationEntity(crs: station.crsCode, name: station.name, isFavourite: favourites.contains(station.crsCode))
        }
    }

    func suggestedEntities() async throws -> [StationEntity] {
        let stations = loadStationCache()
        let favourites = loadFavourites()
        // Show favourites first, then all stations
        let favStations = favourites.compactMap { code in
            stations.first(where: { $0.crsCode == code })
        }.map { StationEntity(crs: $0.crsCode, name: $0.name, isFavourite: true) }

        let otherStations = stations
            .filter { !favourites.contains($0.crsCode) }
            .map { StationEntity(crs: $0.crsCode, name: $0.name, isFavourite: false) }

        return favStations + otherStations
    }

    func defaultResult() async -> StationEntity? {
        let favourites = loadFavourites()
        let stations = loadStationCache()
        guard let code = favourites.first,
              let station = stations.first(where: { $0.crsCode == code }) else { return nil }
        return StationEntity(crs: station.crsCode, name: station.name, isFavourite: true)
    }
}

struct StationEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Station")
    static var defaultQuery = StationQuery()

    var id: String { crs }
    let crs: String
    let name: String
    let isFavourite: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(crs)")
    }
}

struct SingleStationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Station Departures"
    static var description: IntentDescription = "Shows departures from a station."

    @Parameter(title: "Station")
    var station: StationEntity?
}

struct DualStationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Two Station Departures"
    static var description: IntentDescription = "Shows departures from two stations."

    @Parameter(title: "First Station")
    var firstStation: StationEntity?

    @Parameter(title: "Second Station")
    var secondStation: StationEntity?
}

// MARK: - Timeline Entry

struct DepartureEntry: TimelineEntry {
    let date: Date
    let stations: [StationDepartures]

    struct StationDepartures {
        let name: String
        let crs: String
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
        return await fetchEntry(codes: selectedCodes(for: configuration), servicesPerStation: 16)
    }

    func timeline(for configuration: SingleStationIntent, in context: Context) async -> Timeline<DepartureEntry> {
        let entry = await fetchEntry(codes: selectedCodes(for: configuration), servicesPerStation: 16)
        let nextRefresh = Date().addingTimeInterval(300)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func selectedCodes(for config: SingleStationIntent) -> [String] {
        if let station = config.station {
            return [station.crs]
        }
        // Fall back to first favourite
        return Array(loadFavourites().prefix(1))
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
        return await fetchEntry(codes: selectedCodes(for: configuration), servicesPerStation: 8)
    }

    func timeline(for configuration: DualStationIntent, in context: Context) async -> Timeline<DepartureEntry> {
        let entry = await fetchEntry(codes: selectedCodes(for: configuration), servicesPerStation: 8)
        let nextRefresh = Date().addingTimeInterval(300)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func selectedCodes(for config: DualStationIntent) -> [String] {
        var codes: [String] = []
        if let first = config.firstStation { codes.append(first.crs) }
        if let second = config.secondStation { codes.append(second.crs) }
        if codes.isEmpty {
            codes = Array(loadFavourites().prefix(2))
        }
        return codes
    }
}

// MARK: - Shared Fetch Logic

private func fetchEntry(codes: [String], servicesPerStation: Int) async -> DepartureEntry {
    let stations = loadStationCache()
    var stationDepartures: [DepartureEntry.StationDepartures] = []

    for code in codes {
        let name = stations.first(where: { $0.crsCode == code })?.name ?? code
        do {
            let board = try await fetchBoard(crs: code, numRows: servicesPerStation)
            let services = (board.trainServices?.service ?? []).prefix(servicesPerStation).map { service in
                let dest = service.destination.location.map(\.locationName).joined(separator: " & ")
                let status = service.estimated
                let isCancelled = status.lowercased().contains("cancel")
                let isDelayed = status.lowercased().contains("delayed") ||
                    (isTimeFormat(status) && status > service.scheduled)
                return DepartureEntry.WidgetService(
                    id: service.serviceID,
                    scheduled: service.scheduled,
                    destination: dest,
                    platform: service.platform,
                    status: status,
                    isCancelled: isCancelled,
                    isDelayed: isDelayed
                )
            }
            stationDepartures.append(.init(name: name, crs: code, services: Array(services)))
        } catch {
            stationDepartures.append(.init(name: name, crs: code, services: []))
        }
    }

    return DepartureEntry(date: Date(), stations: stationDepartures)
}

private func loadFavourites() -> [String] {
    guard let data = SharedDefaults.shared.data(forKey: SharedDefaults.Keys.favouriteStations) else { return [] }
    return (try? JSONDecoder().decode([String].self, from: data)) ?? []
}

private func loadStationCache() -> [Station] {
    guard let data = SharedDefaults.shared.data(forKey: SharedDefaults.Keys.cachedStations) else { return [] }
    return (try? JSONDecoder().decode([Station].self, from: data)) ?? []
}

private func fetchBoard(crs: String, numRows: Int) async throws -> DepartureBoard {
    var components = URLComponents(string: "https://rail.breslan.co.uk/api/departures/\(crs)")!
    components.queryItems = [URLQueryItem(name: "numRows", value: String(numRows))]
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
                isDelayed: i > 0
            )
        }
        let stations = (0..<stationCount).map { i in
            StationDepartures(
                name: ["London Waterloo", "Clapham Junction"][i % 2],
                crs: ["WAT", "CLJ"][i % 2],
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
                Text(station.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.brand)
                    .lineLimit(1)
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

            if let platform = service.platform {
                Text(platform)
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        colorScheme == .dark ? Theme.platformBadgeDark : Theme.platformBadge,
                        in: RoundedRectangle(cornerRadius: 3)
                    )
                    .frame(width: 28, alignment: .trailing)
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
        .configurationDisplayName("Station Departures")
        .description("Departures from a chosen station.")
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
        .configurationDisplayName("Two Stations")
        .description("Departures from two chosen stations.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
