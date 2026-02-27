//
//  SettingsView.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import SwiftUI

struct SettingsView: View {

    @ObservedObject var viewModel: StationViewModel
    @AppStorage("nearbyStationCount") var nearbyCount: Int = 10
    @AppStorage("recentFilterCount") var recentFilterCount: Int = 3
    @AppStorage("showRecentFilters") var showRecentFilters: Bool = true
    @AppStorage("mapsProvider") var mapsProvider: String = "apple"
    @AppStorage("showNextServiceOnFavourites") var showNextServiceOnFavourites: Bool = true
    @State private var isRefreshing = false
    @State private var lastRefresh: Date? = StationCache.lastRefreshDate()

    var body: some View {
        Form {
            Section("Nearby Stations") {
                Stepper("Show \(nearbyCount) stations", value: $nearbyCount, in: 1...25)
            }

            Section("Favourites") {
                Toggle("Show Next Service", isOn: $showNextServiceOnFavourites)
            }

            Section("Recent Filters") {
                Toggle("Show Recent Filters", isOn: $showRecentFilters)
                if showRecentFilters {
                    Stepper("Keep \(recentFilterCount) recent", value: $recentFilterCount, in: 1...10)
                }
            }

            Section("Maps") {
                Picker("Open in", selection: $mapsProvider) {
                    Text("Apple Maps").tag("apple")
                    Text("Google Maps").tag("google")
                }
            }

            Section("Station Data") {
                HStack {
                    Text("Last Updated")
                    Spacer()
                    if let lastRefresh {
                        Text("\(lastRefresh, style: .relative) ago")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Stations")
                    Spacer()
                    Text("\(viewModel.stations.count)")
                        .foregroundStyle(.secondary)
                }

                Button {
                    isRefreshing = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task {
                        await viewModel.forceRefresh()
                        lastRefresh = StationCache.lastRefreshDate()
                        isRefreshing = false
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                } label: {
                    HStack {
                        Text("Refresh Now")
                        Spacer()
                        if isRefreshing {
                            ProgressView()
                        }
                    }
                }
                .disabled(isRefreshing)
            }
            Section("Debug") {
                HStack {
                    Text("API")
                    Spacer()
                    Text(APIConfig.baseURL)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .navigationTitle("Settings")
    }
}
