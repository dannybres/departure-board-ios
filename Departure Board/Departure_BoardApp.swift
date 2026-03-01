//
//  Departure_BoardApp.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import SwiftUI

// MARK: - Deep Link

enum DeepLink: Equatable {
    case departures(crs: String)
    case arrivals(crs: String)
    case station(crs: String)
    case service(crs: String, serviceId: String)
    case filteredDepartures(crs: String, filterCrs: String, filterType: String)
    case filteredArrivals(crs: String, filterCrs: String, filterType: String)

    init?(url: URL) {
        guard url.scheme == "departure" else { return nil }
        let host = url.host() ?? ""
        let pathParts = url.pathComponents.dropFirst()
        let first = pathParts.first ?? ""
        guard !first.isEmpty else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let filterCrs = queryItems.first(where: { $0.name == "filter" })?.value?.uppercased()
        let filterType = queryItems.first(where: { $0.name == "filterType" })?.value?.lowercased()

        switch host.lowercased() {
        case "departures":
            let crs = first.uppercased()
            if let filterCrs {
                self = .filteredDepartures(crs: crs, filterCrs: filterCrs, filterType: filterType == "to" ? "to" : "from")
            } else {
                self = .departures(crs: crs)
            }
        case "arrivals":
            let crs = first.uppercased()
            if let filterCrs {
                self = .filteredArrivals(crs: crs, filterCrs: filterCrs, filterType: filterType == "to" ? "to" : "from")
            } else {
                self = .arrivals(crs: crs)
            }
        case "station":
            self = .station(crs: first.uppercased())
        case "service":
            let crs = first.uppercased()
            let serviceId = pathParts.dropFirst().first ?? ""
            guard !serviceId.isEmpty else { return nil }
            self = .service(crs: crs, serviceId: serviceId)
        default:
            return nil
        }
    }
}

// MARK: - App

@main
struct Departure_BoardApp: App {
    @State private var pendingDeepLink: DeepLink?

    init() {
        SharedDefaults.migrateIfNeeded()
        UserDefaults.standard.register(defaults: ["autoLoadMode": "off"])
    }

    var body: some Scene {
        WindowGroup {
            ContentView(deepLink: $pendingDeepLink)
                .tint(Theme.brand)
                .onOpenURL { url in
                    pendingDeepLink = DeepLink(url: url)
                }
        }
    }
}
