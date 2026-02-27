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
    @AppStorage("autoLoadMode") var autoLoadMode: String = "nearest"
    @AppStorage("autoLoadDistanceMiles") var autoLoadDistanceMiles: Int = 2
    @State private var isRefreshing = false
    @State private var lastRefresh: Date? = StationCache.lastRefreshDate()

    private var autoLoadModeDescription: String {
        switch autoLoadMode {
        case "off":
            return "The app opens on the station list. Nothing is loaded automatically."
        case "nearest":
            return "The nearest station's departure board is opened automatically."
        case "favourite":
            return "If a favourite board is within \(autoLoadDistanceMiles) mi, it opens automatically. Otherwise the station list is shown."
        case "favouriteOrNearest":
            return "Opens the nearest favourite within \(autoLoadDistanceMiles) mi. If none are close enough, falls back to the nearest station."
        default:
            return ""
        }
    }

    var body: some View {
        Form {
            Section("Nearby Stations") {
                Stepper("Show \(nearbyCount) stations", value: $nearbyCount, in: 1...25)
            }

            Section {
                Toggle("Show Next Service", isOn: $showNextServiceOnFavourites)
            } header: {
                Text("Favourites")
            }

            Section {
                Picker("On Launch", selection: $autoLoadMode) {
                    Text("Disabled").tag("off")
                    Text("Nearest Station").tag("nearest")
                    Text("Nearby Favourite").tag("favourite")
                    Text("Favourite, then Nearest").tag("favouriteOrNearest")
                }

                if autoLoadMode == "favourite" || autoLoadMode == "favouriteOrNearest" {
                    Stepper("Within \(autoLoadDistanceMiles) mi", value: $autoLoadDistanceMiles, in: 1...50)
                }

                Text(autoLoadModeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Auto-Load on Launch")
            } footer: {
                if autoLoadMode == "favourite" || autoLoadMode == "favouriteOrNearest" {
                    Text("When multiple favourites are within range, the one highest in your favourites list is loaded — not the closest. Reorder your favourites to control which board opens first.")
                        .font(.caption)
                }
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
        Section {
            Text("You can open specific boards directly from Safari, Shortcuts, or any app that supports custom URLs. Just tap a link or build your own.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.bottom, 4)

            ForEach(urlSchemeExamples, id: \.url) { example in
                VStack(alignment: .leading, spacing: 3) {
                    Text(example.title)
                        .font(.subheadline.weight(.medium))
                    Text(example.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(example.url)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.brand)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if let url = URL(string: example.url) {
                        UIApplication.shared.open(url)
                    }
                }
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = example.url
                    } label: {
                        Label("Copy URL", systemImage: "doc.on.doc")
                    }
                    Button {
                        if let url = URL(string: example.url) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open", systemImage: "arrow.up.right.square")
                    }
                }
            }
        } header: {
            Label("URL Scheme", systemImage: "link")
        } footer: {
            Text("Tap any example to open it. Long press to copy the URL.")
        }

        .navigationTitle("Settings")
    }

    private struct URLSchemeExample {
        let title: String
        let description: String
        let url: String
    }

    private let urlSchemeExamples: [URLSchemeExample] = [
        URLSchemeExample(
            title: "Departures from Manchester Piccadilly",
            description: "Opens the departures board for a station. Replace MAN with any CRS code.",
            url: "departure://departures/MAN"
        ),
        URLSchemeExample(
            title: "Arrivals at Leeds",
            description: "Opens the arrivals board instead of departures.",
            url: "departure://arrivals/LDS"
        ),
        URLSchemeExample(
            title: "Station information for York",
            description: "Opens the station info sheet — facilities, access, parking and more.",
            url: "departure://station/YRK"
        ),
        URLSchemeExample(
            title: "Departures from Liverpool Lime Street",
            description: "Another departures example — great for a Shortcuts widget or home screen bookmark.",
            url: "departure://departures/LIV"
        ),
        URLSchemeExample(
            title: "Arrivals at Newcastle",
            description: "Useful if you are meeting someone off a train and want to check arrivals quickly.",
            url: "departure://arrivals/NCL"
        ),
    ]
}
