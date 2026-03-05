import Foundation
import AppIntents

struct StationEntity: AppEntity, Identifiable {
    let id: String // CRS
    let name: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Station")
    static var defaultQuery = StationEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(id)")
    }
}

struct StationEntityQuery: EntityStringQuery {
    nonisolated init() {}

    func entities(for identifiers: [StationEntity.ID]) async throws -> [StationEntity] {
        let stations = await MainActor.run { StationCache.load() ?? [] }
        let wanted = Set(identifiers.map { $0.uppercased() })
        return stations
            .filter { wanted.contains($0.crsCode.uppercased()) }
            .map { StationEntity(id: $0.crsCode, name: $0.name) }
    }

    func entities(matching string: String) async throws -> [StationEntity] {
        let stations = await MainActor.run { StationCache.load() ?? [] }
        if string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Array(stations.prefix(25)).map { StationEntity(id: $0.crsCode, name: $0.name) }
        }
        return stations
            .filter {
                $0.name.localizedCaseInsensitiveContains(string)
                || $0.crsCode.localizedCaseInsensitiveContains(string)
            }
            .prefix(25)
            .map { StationEntity(id: $0.crsCode, name: $0.name) }
    }

    func suggestedEntities() async throws -> [StationEntity] {
        let routes = await MainActor.run { RoutineEngine.shared.topLikelyRoutes(limit: 8) }
        let stationsByCRS = await MainActor.run {
            Dictionary(uniqueKeysWithValues: (StationCache.load() ?? []).map { ($0.crsCode, $0) })
        }
        let likely = routes.compactMap { route -> StationEntity? in
            guard let station = stationsByCRS[route.crs] else { return nil }
            return StationEntity(id: station.crsCode, name: station.name)
        }
        if !likely.isEmpty { return likely }
        let fallback = await MainActor.run { StationCache.load() ?? [] }
        return fallback.prefix(12).map { StationEntity(id: $0.crsCode, name: $0.name) }
    }
}

struct FavouriteBoardEntity: AppEntity, Identifiable {
    let id: String // boardID
    let title: String
    let subtitle: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Favourite Board")
    static var defaultQuery = FavouriteBoardEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }
}

struct FavouriteBoardEntityQuery: EntityStringQuery {
    nonisolated init() {}

    func entities(for identifiers: [FavouriteBoardEntity.ID]) async throws -> [FavouriteBoardEntity] {
        let all = await makeFavouriteEntities()
        let wanted = Set(identifiers)
        return all.filter { wanted.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [FavouriteBoardEntity] {
        let all = await makeFavouriteEntities()
        if string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return all
        }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(string)
            || $0.subtitle.localizedCaseInsensitiveContains(string)
            || $0.id.localizedCaseInsensitiveContains(string)
        }
    }

    func suggestedEntities() async throws -> [FavouriteBoardEntity] {
        await makeFavouriteEntities()
    }

    private func makeFavouriteEntities() async -> [FavouriteBoardEntity] {
        let boards = await MainActor.run { SharedDefaults.loadFavouriteBoards() }
        let stationMap = await MainActor.run {
            Dictionary(uniqueKeysWithValues: (StationCache.load() ?? []).map { ($0.crsCode, $0.name) })
        }

        let parsedPairs = await MainActor.run {
            boards.compactMap { id -> (String, ParsedBoardID)? in
                guard let parsed = SharedDefaults.parseBoardID(id) else { return nil }
                return (id, parsed)
            }
        }

        return parsedPairs.compactMap { pair in
            let id = pair.0
            let parsed = pair.1
            let stationName = stationMap[parsed.crs] ?? parsed.crs
            let boardLabel = parsed.boardType == .departures ? "Departures" : "Arrivals"

            if let filterCrs = parsed.filterCrs {
                let filterName = stationMap[filterCrs] ?? filterCrs
                let direction = parsed.filterType == "to" ? "to" : "from"
                return FavouriteBoardEntity(
                    id: id,
                    title: "\(stationName) \(boardLabel)",
                    subtitle: "\(direction.capitalized) \(filterName)"
                )
            }
            return FavouriteBoardEntity(id: id, title: "\(stationName) \(boardLabel)", subtitle: "Favourite")
        }
    }
}

enum IntentBoardType: String, AppEnum {
    case departures
    case arrivals

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Board Type")
    static var caseDisplayRepresentations: [IntentBoardType: DisplayRepresentation] = [
        .departures: DisplayRepresentation(title: "Departures"),
        .arrivals: DisplayRepresentation(title: "Arrivals")
    ]

    var boardType: BoardType { self == .departures ? .departures : .arrivals }
}

enum IntentFilterDirection: String, AppEnum {
    case to
    case from

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Filter Direction")
    static var caseDisplayRepresentations: [IntentFilterDirection: DisplayRepresentation] = [
        .to: DisplayRepresentation(title: "To (calling at)"),
        .from: DisplayRepresentation(title: "From")
    ]
}
