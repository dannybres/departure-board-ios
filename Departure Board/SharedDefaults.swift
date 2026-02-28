//
//  SharedDefaults.swift
//  Departure Board
//

import Foundation

enum BoardType: String, CaseIterable, Codable {
    case departures
    case arrivals
}

// Decoded representation of a board ID string.
struct ParsedBoardID: Identifiable {
    var id: String { SharedDefaults.boardID(crs: crs, boardType: boardType, filterCrs: filterCrs, filterType: filterType) }
    let crs: String
    let boardType: BoardType
    let filterCrs: String?
    let filterType: String? // "to" or "from"

    var isFiltered: Bool { filterCrs != nil }
}

enum APIConfig {
//    static let baseURL = "https://railtest.breslan.co.uk/api/v1"
    static let baseURL = "https://rail.breslan.co.uk/api/v1"
}

enum SharedDefaults {
    static let suiteName = "group.com.breslan.Departure-Board"
    static let shared = UserDefaults(suiteName: suiteName)!

    enum Keys {
        static let favouriteStations = "favouriteStations"  // widget-compat, synced from favouriteBoards
        static let favouriteBoards   = "favouriteBoards"    // [String] unified new format
        static let recentFilters     = "recentFilters"      // [String] recent filter board IDs
        static let cachedStations    = "cachedStations"
        static let stationsLastRefresh = "stationsLastRefresh"
        static let didMigrateToSharedSuite = "didMigrateToSharedSuite"
    }

    // MARK: - ID encoding / decoding

    /// Encodes a board into its compact string ID.
    /// Plain:    "BEB-dep", "PLY-arr"
    /// Filtered: "EUS-dep-to-LIV", "BEB-dep-from-CTR"
    static func boardID(crs: String, boardType: BoardType, filterCrs: String? = nil, filterType: String? = nil) -> String {
        let bt = boardType == .departures ? "dep" : "arr"
        if let fc = filterCrs, let ft = filterType {
            return "\(crs)-\(bt)-\(ft)-\(fc)"
        }
        return "\(crs)-\(bt)"
    }

    /// Decodes a board ID string back into its components.
    static func parseBoardID(_ id: String) -> ParsedBoardID? {
        let parts = id.split(separator: "-").map(String.init)
        guard parts.count >= 2 else { return nil }
        let crs = parts[0]
        let bt: BoardType
        switch parts[1] {
        case "dep": bt = .departures
        case "arr": bt = .arrivals
        default: return nil
        }
        if parts.count == 4, parts[2] == "to" || parts[2] == "from" {
            return ParsedBoardID(crs: crs, boardType: bt, filterCrs: parts[3], filterType: parts[2])
        }
        guard parts.count == 2 else { return nil }
        return ParsedBoardID(crs: crs, boardType: bt, filterCrs: nil, filterType: nil)
    }

    // MARK: - Favourites

    static func loadFavouriteBoards() -> [String] {
        guard let data = shared.data(forKey: Keys.favouriteBoards) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    static func saveFavouriteBoards(_ boards: [String]) {
        if let data = try? JSONEncoder().encode(boards) {
            shared.set(data, forKey: Keys.favouriteBoards)
        }
    }

    // MARK: - Recent Filters

    static func loadRecentFilters() -> [String] {
        guard let data = shared.data(forKey: Keys.recentFilters) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    static func addRecentFilter(id: String) {
        var recents = loadRecentFilters()
        recents.removeAll { $0 == id }
        recents.insert(id, at: 0)
        let limit = UserDefaults.standard.object(forKey: "recentFilterCount") as? Int ?? 3
        recents = Array(recents.prefix(limit))
        if let data = try? JSONEncoder().encode(recents) {
            shared.set(data, forKey: Keys.recentFilters)
        }
    }

    static func removeRecentFilter(id: String) {
        var recents = loadRecentFilters()
        recents.removeAll { $0 == id }
        if let data = try? JSONEncoder().encode(recents) {
            shared.set(data, forKey: Keys.recentFilters)
        }
    }

    // MARK: - Widget sync

    /// Keeps the legacy favouriteStations key (bare CRS array) in sync so the widget can still read it.
    static func syncStationFavourites(from boards: [String], allStationCodes: Set<String>) {
        let stationOnly = boards.compactMap { id -> String? in
            guard let parsed = parseBoardID(id), !parsed.isFiltered,
                  allStationCodes.contains(parsed.crs) else { return nil }
            return parsed.crs
        }
        var seen = Set<String>()
        let unique = stationOnly.filter { seen.insert($0).inserted }
        if let data = try? JSONEncoder().encode(unique) {
            shared.set(data, forKey: Keys.favouriteStations)
        }
    }

    // MARK: - Migration (shared suite)

    static func migrateIfNeeded() {
        guard !shared.bool(forKey: Keys.didMigrateToSharedSuite) else { return }
        let old = UserDefaults.standard

        if let data = old.data(forKey: Keys.favouriteStations), shared.data(forKey: Keys.favouriteStations) == nil {
            shared.set(data, forKey: Keys.favouriteStations)
        }
        if let data = old.data(forKey: Keys.cachedStations), shared.data(forKey: Keys.cachedStations) == nil {
            shared.set(data, forKey: Keys.cachedStations)
        }
        if let date = old.object(forKey: Keys.stationsLastRefresh) as? Date,
           shared.object(forKey: Keys.stationsLastRefresh) == nil {
            shared.set(date, forKey: Keys.stationsLastRefresh)
        }

        shared.set(true, forKey: Keys.didMigrateToSharedSuite)
    }
}
