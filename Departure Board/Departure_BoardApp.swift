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

    init?(url: URL) {
        guard url.scheme == "departure" else { return nil }
        let host = url.host() ?? ""
        let crs = url.pathComponents.dropFirst().first ?? ""
        guard !crs.isEmpty else { return nil }
        let upperCrs = crs.uppercased()

        switch host.lowercased() {
        case "departures":
            self = .departures(crs: upperCrs)
        case "arrivals":
            self = .arrivals(crs: upperCrs)
        case "station":
            self = .station(crs: upperCrs)
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
