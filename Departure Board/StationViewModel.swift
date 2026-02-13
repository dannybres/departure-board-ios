//
//  StationViewModel.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import Foundation
import Combine

@MainActor
class StationViewModel: ObservableObject {

    @Published var stations: [Station] = []
        
    init() {
        loadCachedStations()
        refreshIfNeeded()
    }
    
    func reloadFromCache() {
        loadCachedStations()
    }

    func forceRefresh() async {
        await fetchStationsInBackground()
    }

    private func loadCachedStations() {
        if let cached = StationCache.load() {
            stations = cached
        }
    }
    
    private func refreshIfNeeded() {
        guard StationCache.isExpired() else { return }
        
        Task {
            await fetchStationsInBackground()
        }
    }
    
    private func fetchStationsInBackground() async {
        guard let url = URL(string: "https://rail.breslan.co.uk/api/stations") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([Station].self, from: data)
            
            StationCache.save(decoded)
            
            // Only update if data actually changed
            if decoded != stations {
                stations = decoded
            }
            
        } catch {
            print("Background refresh failed:", error)
        }
    }

    func fetchServiceDetail(serviceID: String) async throws -> ServiceDetail {
        guard let url = URL(string: "https://rail.breslan.co.uk/api/service/\(serviceID)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ServiceDetail.self, from: data)
    }

    func fetchBoard(for crs: String, type: BoardType = .departures) async throws -> DepartureBoard {
        let urlString = "https://rail.breslan.co.uk/api/\(type.rawValue)/\(crs)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoded = try JSONDecoder().decode(DepartureBoard.self, from: data)

        return decoded
    }

}
