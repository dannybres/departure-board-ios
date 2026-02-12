//
//  StationCache.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import Foundation

struct StationCache {
    
    private static let stationsKey = "cachedStations"
    private static let lastRefreshKey = "stationsLastRefresh"
    
    static func save(_ stations: [Station]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(stations) {
            UserDefaults.standard.set(data, forKey: stationsKey)
            UserDefaults.standard.set(Date(), forKey: lastRefreshKey)
        }
    }
    
    static func load() -> [Station]? {
        guard let data = UserDefaults.standard.data(forKey: stationsKey) else {
            return nil
        }
        return try? JSONDecoder().decode([Station].self, from: data)
    }
    
    static func isExpired(maxAge: TimeInterval = 86400) -> Bool {
        guard let lastRefresh = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastRefresh) > maxAge
    }
}

