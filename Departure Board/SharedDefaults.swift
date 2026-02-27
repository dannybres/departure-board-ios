//
//  SharedDefaults.swift
//  Departure Board
//

import Foundation

enum BoardType: String, CaseIterable, Codable {
    case departures
    case arrivals
}

struct SavedFilter: Codable, Identifiable, Equatable, Hashable {
    let stationCrs: String
    let stationName: String
    let filterCrs: String
    let filterName: String
    let filterType: String
    var boardType: BoardType = .departures
    var isFavourite: Bool = false

    var id: String { "\(stationCrs)-\(boardType.rawValue)-\(filterType)-\(filterCrs)" }

    enum CodingKeys: String, CodingKey {
        case stationCrs, stationName, filterCrs, filterName, filterType, boardType, isFavourite
    }

    init(stationCrs: String, stationName: String, filterCrs: String, filterName: String, filterType: String, boardType: BoardType = .departures, isFavourite: Bool = false) {
        self.stationCrs = stationCrs
        self.stationName = stationName
        self.filterCrs = filterCrs
        self.filterName = filterName
        self.filterType = filterType
        self.boardType = boardType
        self.isFavourite = isFavourite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stationCrs = try container.decode(String.self, forKey: .stationCrs)
        stationName = try container.decode(String.self, forKey: .stationName)
        filterCrs = try container.decode(String.self, forKey: .filterCrs)
        filterName = try container.decode(String.self, forKey: .filterName)
        filterType = try container.decode(String.self, forKey: .filterType)
        boardType = (try? container.decode(BoardType.self, forKey: .boardType)) ?? .departures
        isFavourite = (try? container.decode(Bool.self, forKey: .isFavourite)) ?? false
    }

    var filterLabel: String {
        filterType == "to" ? "Calling at \(filterName)" : "From \(filterName)"
    }

    static func load() -> [SavedFilter] {
        guard let data = SharedDefaults.shared.data(forKey: SharedDefaults.Keys.savedFilters) else { return [] }
        return (try? JSONDecoder().decode([SavedFilter].self, from: data)) ?? []
    }

    static func save(_ filters: [SavedFilter]) {
        if let data = try? JSONEncoder().encode(filters) {
            SharedDefaults.shared.set(data, forKey: SharedDefaults.Keys.savedFilters)
        }
    }

    static func addRecent(stationCrs: String, stationName: String, filterCrs: String, filterName: String, filterType: String, boardType: BoardType) {
        var all = load()
        let newFilter = SavedFilter(stationCrs: stationCrs, stationName: stationName, filterCrs: filterCrs, filterName: filterName, filterType: filterType, boardType: boardType)

        // Don't duplicate — if it exists as recent, just move to front
        if let idx = all.firstIndex(where: { $0.id == newFilter.id }) {
            if all[idx].isFavourite { return }
            all.remove(at: idx)
        }

        // Insert at start of recents (after favourites)
        let firstRecentIdx = all.firstIndex(where: { !$0.isFavourite }) ?? all.count
        all.insert(newFilter, at: firstRecentIdx)

        // Trim recents to configured limit
        let recentLimit = UserDefaults.standard.object(forKey: "recentFilterCount") as? Int ?? 3
        let favourites = all.filter { $0.isFavourite }
        let recents = all.filter { !$0.isFavourite }.prefix(recentLimit)
        save(favourites + recents)
    }
}

enum APIConfig {
    static let baseURL = "https://railtest.breslan.co.uk/api/v1"
//    static let baseURL = "https://rail.breslan.co.uk/api/v1"
}

enum SharedDefaults {
    static let suiteName = "group.com.breslan.Departure-Board"
    static let shared = UserDefaults(suiteName: suiteName)!

    enum Keys {
        static let favouriteStations = "favouriteStations"
        static let favouriteItems = "favouriteItems"
        static let cachedStations = "cachedStations"
        static let stationsLastRefresh = "stationsLastRefresh"
        static let didMigrateToSharedSuite = "didMigrateToSharedSuite"
        static let savedFilters = "savedFilters"
    }

    static func migrateIfNeeded() {
        guard !shared.bool(forKey: Keys.didMigrateToSharedSuite) else { return }
        let old = UserDefaults.standard

        if let data = old.data(forKey: Keys.favouriteStations), shared.data(forKey: Keys.favouriteStations) == nil {
            shared.set(data, forKey: Keys.favouriteStations)
        }

        if let data = old.data(forKey: Keys.cachedStations), shared.data(forKey: Keys.cachedStations) == nil {
            shared.set(data, forKey: Keys.cachedStations)
        }
        if let date = old.object(forKey: Keys.stationsLastRefresh) as? Date, shared.object(forKey: Keys.stationsLastRefresh) == nil {
            shared.set(date, forKey: Keys.stationsLastRefresh)
        }

        shared.set(true, forKey: Keys.didMigrateToSharedSuite)
    }

    /// Migrate legacy favourite items (bare CRS codes) to board-type-aware format
    static func migrateFavouriteItemsIfNeeded() {
        guard let data = shared.data(forKey: Keys.favouriteItems),
              let items = try? JSONDecoder().decode([String].self, from: data),
              !items.isEmpty else { return }

        // If any item is a bare CRS (no hyphen), migrate all bare ones to departures
        let needsMigration = items.contains { !$0.contains("-") }
        guard needsMigration else { return }

        let migrated = items.map { item in
            item.contains("-") ? item : "\(item)-departures"
        }
        if let newData = try? JSONEncoder().encode(migrated) {
            shared.set(newData, forKey: Keys.favouriteItems)
        }
    }

    /// Sync the widget-compatible favouriteStations key from favouriteItems
    static func syncStationFavourites(from items: [String], allStationCodes: Set<String>) {
        // Extract CRS codes from board-type-aware IDs like "WAT-departures"
        let stationOnly = items.compactMap { item -> String? in
            let parts = item.split(separator: "-")
            guard parts.count == 2,
                  let crs = parts.first.map(String.init),
                  allStationCodes.contains(crs) else { return nil }
            return crs
        }
        // Deduplicate while preserving order
        var seen = Set<String>()
        let unique = stationOnly.filter { seen.insert($0).inserted }
        if let data = try? JSONEncoder().encode(unique) {
            shared.set(data, forKey: Keys.favouriteStations)
        }
    }

    /// Helper to build a station favourite ID
    static func stationFavID(crs: String, boardType: BoardType) -> String {
        "\(crs)-\(boardType.rawValue)"
    }

    /// Parse a favourite item ID to extract CRS and board type (for station items only)
    static func parseStationFavID(_ id: String) -> (crs: String, boardType: BoardType)? {
        let parts = id.split(separator: "-")
        guard parts.count == 2,
              let boardType = BoardType(rawValue: String(parts[1])) else { return nil }
        return (String(parts[0]), boardType)
    }
}
