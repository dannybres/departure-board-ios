//
//  SharedDefaults.swift
//  Departure Board
//

import Foundation

enum BoardType: String, CaseIterable {
    case departures
    case arrivals
}

struct SavedFilter: Codable, Identifiable, Equatable, Hashable {
    let stationCrs: String
    let stationName: String
    let filterCrs: String
    let filterName: String
    let filterType: String
    var isFavourite: Bool = false

    var id: String { "\(stationCrs)-\(filterType)-\(filterCrs)" }

    static func load() -> [SavedFilter] {
        guard let data = SharedDefaults.shared.data(forKey: SharedDefaults.Keys.savedFilters) else { return [] }
        return (try? JSONDecoder().decode([SavedFilter].self, from: data)) ?? []
    }

    static func save(_ filters: [SavedFilter]) {
        if let data = try? JSONEncoder().encode(filters) {
            SharedDefaults.shared.set(data, forKey: SharedDefaults.Keys.savedFilters)
        }
    }

    static func addRecent(stationCrs: String, stationName: String, filterCrs: String, filterName: String, filterType: String) {
        var all = load()
        let newFilter = SavedFilter(stationCrs: stationCrs, stationName: stationName, filterCrs: filterCrs, filterName: filterName, filterType: filterType)

        // Don't duplicate — if it exists as recent, just move to front
        if let idx = all.firstIndex(where: { $0.id == newFilter.id }) {
            if all[idx].isFavourite { return } // Already saved as favourite, nothing to do
            all.remove(at: idx)
        }

        // Insert at start of recents (after favourites)
        let firstRecentIdx = all.firstIndex(where: { !$0.isFavourite }) ?? all.count
        all.insert(newFilter, at: firstRecentIdx)

        // Trim recents to 5
        let favourites = all.filter { $0.isFavourite }
        let recents = all.filter { !$0.isFavourite }.prefix(5)
        save(favourites + recents)
    }
}

enum SharedDefaults {
    static let suiteName = "group.com.breslan.Departure-Board"
    static let shared = UserDefaults(suiteName: suiteName)!

    enum Keys {
        static let favouriteStations = "favouriteStations"
        static let cachedStations = "cachedStations"
        static let stationsLastRefresh = "stationsLastRefresh"
        static let didMigrateToSharedSuite = "didMigrateToSharedSuite"
        static let savedFilters = "savedFilters"
    }

    static func migrateIfNeeded() {
        guard !shared.bool(forKey: Keys.didMigrateToSharedSuite) else { return }
        let old = UserDefaults.standard

        // Migrate favourites
        if let data = old.data(forKey: Keys.favouriteStations), shared.data(forKey: Keys.favouriteStations) == nil {
            shared.set(data, forKey: Keys.favouriteStations)
        }

        // Migrate station cache
        if let data = old.data(forKey: Keys.cachedStations), shared.data(forKey: Keys.cachedStations) == nil {
            shared.set(data, forKey: Keys.cachedStations)
        }
        if let date = old.object(forKey: Keys.stationsLastRefresh) as? Date, shared.object(forKey: Keys.stationsLastRefresh) == nil {
            shared.set(date, forKey: Keys.stationsLastRefresh)
        }

        shared.set(true, forKey: Keys.didMigrateToSharedSuite)
    }
}
