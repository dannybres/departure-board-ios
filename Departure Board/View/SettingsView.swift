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
    @AppStorage("mapsProvider") var mapsProvider: String = "apple"
    @State private var isRefreshing = false
    @State private var lastRefresh: Date? = StationCache.lastRefreshDate()

    var body: some View {
        Form {
            Section("Nearby Stations") {
                Stepper("Show \(nearbyCount) stations", value: $nearbyCount, in: 1...25)
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
                    Task {
                        await viewModel.forceRefresh()
                        lastRefresh = StationCache.lastRefreshDate()
                        isRefreshing = false
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
        }
        .navigationTitle("Settings")
    }
}
