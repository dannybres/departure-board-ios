//
//  SharedDefaults.swift
//  Departure Board
//

import Foundation

enum BoardType: String, CaseIterable {
    case departures
    case arrivals
}

enum SharedDefaults {
    static let suiteName = "group.com.breslan.Departure-Board"
    static let shared = UserDefaults(suiteName: suiteName)!

    enum Keys {
        static let favouriteStations = "favouriteStations"
        static let cachedStations = "cachedStations"
        static let stationsLastRefresh = "stationsLastRefresh"
        static let didMigrateToSharedSuite = "didMigrateToSharedSuite"
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
