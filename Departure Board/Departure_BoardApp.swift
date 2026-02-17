//
//  Departure_BoardApp.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import SwiftUI

enum DeepLink: Equatable {
    case departures(crs: String)
    case arrivals(crs: String)
    case station(crs: String)
    case service(crs: String, serviceID: String)

    init?(url: URL) {
        guard url.scheme == "departure" else { return nil }
        let host = url.host() ?? ""
        let pathParts = url.pathComponents.dropFirst()
        let first = pathParts.first ?? ""
        guard !first.isEmpty else { return nil }

        switch host.lowercased() {
        case "departures":
            self = .departures(crs: first.uppercased())
        case "arrivals":
            self = .arrivals(crs: first.uppercased())
        case "station":
            self = .station(crs: first.uppercased())
        case "service":
            let crs = first.uppercased()
            let serviceID = pathParts.dropFirst().first ?? ""
            guard !serviceID.isEmpty else { return nil }
            self = .service(crs: crs, serviceID: serviceID)
        default:
            return nil
        }
    }
}

@main
struct Departure_BoardApp: App {
    @State private var pendingDeepLink: DeepLink?

    init() {
        SharedDefaults.migrateIfNeeded()
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
