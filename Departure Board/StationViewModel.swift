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
        guard let url = URL(string: "\(APIConfig.baseURL)/stations") else { return }
        
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

    static func fetchStationInfo(crs: String) async throws -> StationInfo {
        guard let url = URL(string: "\(APIConfig.baseURL)/station/\(crs)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(StationInfo.self, from: data)
    }

    static func fetchServiceDetail(serviceId: String) async throws -> ServiceDetail {
        guard let url = URL(string: "\(APIConfig.baseURL)/service/\(serviceId)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ServiceDetail.self, from: data)
    }

    static func fetchBoard(
        for crs: String,
        type: BoardType = .departures,
        numRows: Int? = nil,
        filterCrs: String? = nil,
        filterType: String? = nil,
        timeOffset: Int? = nil,
        timeWindow: Int? = nil
    ) async throws -> DepartureBoard {
        var components = URLComponents(string: "\(APIConfig.baseURL)/\(type.rawValue)/\(crs)")!
        var queryItems: [URLQueryItem] = []
        if let numRows { queryItems.append(URLQueryItem(name: "numRows", value: String(numRows))) }
        if let filterCrs { queryItems.append(URLQueryItem(name: "filterCrs", value: filterCrs)) }
        if let filterType { queryItems.append(URLQueryItem(name: "filterType", value: filterType)) }
        if let timeOffset { queryItems.append(URLQueryItem(name: "timeOffset", value: String(timeOffset))) }
        if let timeWindow { queryItems.append(URLQueryItem(name: "timeWindow", value: String(timeWindow))) }
        if !queryItems.isEmpty { components.queryItems = queryItems }

        guard let url = components.url else {
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
