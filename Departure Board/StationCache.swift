//
//  StationCache.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import Foundation

struct StationCache {

    private static let stationsKey = SharedDefaults.Keys.cachedStations
    private static let lastRefreshKey = SharedDefaults.Keys.stationsLastRefresh
    private static let defaults = SharedDefaults.shared
    private static var inMemoryCache: [Station]?

    static func save(_ stations: [Station]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(stations) {
            defaults.set(data, forKey: stationsKey)
            defaults.set(Date(), forKey: lastRefreshKey)
        }
        inMemoryCache = stations
    }

    static func load() -> [Station]? {
        if let cached = inMemoryCache {
            return cached
        }
        guard let data = defaults.data(forKey: stationsKey) else {
            return nil
        }
        let decoded = try? JSONDecoder().decode([Station].self, from: data)
        inMemoryCache = decoded
        return decoded
    }
    
    static func lastRefreshDate() -> Date? {
        defaults.object(forKey: lastRefreshKey) as? Date
    }

    static func isExpired(maxAge: TimeInterval = 86400) -> Bool {
        guard let lastRefresh = lastRefreshDate() else {
            return true
        }
        return Date().timeIntervalSince(lastRefresh) > maxAge
    }
}

