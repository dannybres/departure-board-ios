//
//  SubscribeView.swift
//  Departure Board
//

import SwiftUI

// MARK: - Page model

enum PaywallFeature {
    case widgets
    case lockScreen
    case themes
    case favourites
    case travelMode
    case serviceDetail
    case stationInfo
    case autoLoad
    case all

    var page: Int {
        switch self {
        case .widgets: 0
        case .lockScreen: 1
        case .themes: 2
        case .favourites: 3
        case .travelMode: 4
        case .serviceDetail: 5
        case .stationInfo: 6
        case .autoLoad: 7
        case .all: 8
        }
    }
}

private struct PaywallPage: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let subtitle: String
    let preview: AnyView
}

// MARK: - Main sheet

struct SubscribeView: View {

    @Environment(\.dismiss) private var dismiss
    private let initialFeature: PaywallFeature
    @State private var currentPage: Int

    init(initialFeature: PaywallFeature = .all) {
        self.initialFeature = initialFeature
        _currentPage = State(initialValue: initialFeature.page)
    }

    private let pages: [PaywallPage] = [
        PaywallPage(
            id: 0,
            icon: "star.fill",
            title: "Live on Your Home Screen",
            subtitle: "Glance at your next train without even opening the app. Small, medium, and large widgets — for one station or two at once.",
            preview: AnyView(WidgetPreview())
        ),
        PaywallPage(
            id: 1,
            icon: "lock.iphone",
            title: "Lock Screen Widgets",
            subtitle: "See your next train directly on your Lock Screen with glanceable inline, circular, and rectangular layouts.",
            preview: AnyView(WidgetPreview())
        ),
        PaywallPage(
            id: 2,
            icon: "paintpalette.fill",
            title: "Boards That Turn Heads",
            subtitle: "Choose from seven row styles and full operator livery colours. Your board, your look — from subtle to striking.",
            preview: AnyView(ThemePreview())
        ),
        PaywallPage(
            id: 3,
            icon: "star.leadinghalf.filled",
            title: "Your Stations, Unlimited",
            subtitle: "Star as many stations as you like and see your next departure right on the card — tap to jump straight to the service.",
            preview: AnyView(FavouritesPreview())
        ),
        PaywallPage(
            id: 4,
            icon: "clock.arrow.circlepath",
            title: "See Earlier & Later Trains",
            subtitle: "Jump forward or back in time on any board. Perfect for planning connections or checking if you've already missed the last train.",
            preview: AnyView(TravelModePreview())
        ),
        PaywallPage(
            id: 5,
            icon: "list.bullet.rectangle.fill",
            title: "Every Stop, Every Detail",
            subtitle: "The full calling-point timeline with live delays at each stop, plus carriage formation and live loading percentages where available.",
            preview: AnyView(ServiceDetailPreview())
        ),
        PaywallPage(
            id: 6,
            icon: "building.2.fill",
            title: "Know Your Station",
            subtitle: "Ticket office hours, accessibility facilities, car parking, toilets, left luggage, and more — all in one place.",
            preview: AnyView(StationInfoPreview())
        ),
        PaywallPage(
            id: 7,
            icon: "bolt.fill",
            title: "Opens the Right Board, Automatically",
            subtitle: "The app opens your nearest favourite board the moment you arrive at a station. Hook it into Shortcuts for full automation.",
            preview: AnyView(AutoloadPreview())
        ),
        PaywallPage(
            id: 8,
            icon: "checkmark.seal.fill",
            title: "Everything in One Subscription",
            subtitle: "One price unlocks it all — and everything that comes next.",
            preview: AnyView(AllFeaturesPreview())
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            carousel
            bottomBar
        }
        .onAppear {
            currentPage = initialFeature.page
        }
        .ignoresSafeArea(edges: .bottom)
        .presentationBackground(.regularMaterial)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "train.side.front.car")
                .font(.system(size: 36))
                .foregroundStyle(Theme.brand)
                .padding(.top, 28)

            Text("Unlock Departure Board")
                .font(.title2.bold())

            Text("Everything you need to never miss a train.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }

    // MARK: - Carousel

    private var carousel: some View {
        VStack(spacing: 12) {
            TabView(selection: $currentPage) {
                ForEach(pages) { page in
                    pageCard(page)
                        .tag(page.id)
                        .padding(.horizontal, 20)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 420)
            .background(Color.clear)

            // Page dots
            HStack(spacing: 6) {
                ForEach(pages) { page in
                    Circle()
                        .fill(currentPage == page.id ? Theme.brand : Color(.tertiaryLabel))
                        .frame(width: currentPage == page.id ? 8 : 6, height: currentPage == page.id ? 8 : 6)
                        .animation(.spring(duration: 0.25), value: currentPage)
                }
            }
        }
    }

    private func pageCard(_ page: PaywallPage) -> some View {
        VStack(spacing: 0) {
            // Preview area
            page.preview
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            // Text area
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: page.icon)
                        .foregroundStyle(Theme.brand)
                    Text(page.title)
                        .font(.headline)
                }
                Text(page.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            .padding(.top, 16)
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            Button {
                // TODO: trigger StoreKit purchase
            } label: {
                Text("Subscribe — £2.99 / month")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.brand, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 16)

            HStack(spacing: 20) {
                Button("Restore") { /* TODO */ }
                Button("Privacy") { /* TODO */ }
                Button("Terms") { /* TODO */ }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("Cancel anytime. Subscription renews monthly.")
                .font(.caption2)
                .foregroundStyle(Color(.tertiaryLabel))
                .padding(.bottom, 8)
        }
        .padding(.bottom, 24)
    }
}

// MARK: - Feature previews

// MARK: Widgets

private struct WidgetPreview: View {
    var body: some View {
        ZStack {
            Color.clear
            VStack(spacing: 10) {
                // Medium widget mock
                MockWidget(station: "Arendelle Central", rows: [
                    ("07:42", "North Mountain", "On time", "1"),
                    ("07:55", "Enchanted Forest", "On time", "3"),
                    ("08:03", "Weselton Intl", "Delayed", "2"),
                    ("08:17", "Ahtohallan",     "On time", "5"),
                ])
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .padding()
        }
    }
}

private struct MockWidget: View {
    let station: String
    let rows: [(String, String, String, String)]

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
            VStack(alignment: .leading, spacing: 0) {
                Text(station.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.brand)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        Text(row.0)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 44, alignment: .leading)
                        Text(row.1)
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.2)
                            .font(.system(size: 10))
                            .foregroundStyle(row.2 == "On time" ? .green : .orange)
                            .lineLimit(1)
                        Text(row.3)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 4))
                            .padding(.leading, 6)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
                Spacer()
            }
        }
    }
}

// MARK: Themes

private struct ThemePreview: View {
    // (time, destination, toc, platform, isDelayed, delayText)
    private let rows: [(String, String, String, Color, String, Bool, String?)] = [
        ("08:14", "North Mountain",    "GR", "1", false, nil),
        ("08:22", "Weselton Intl",     "TP", "3", true,  "Exp 08:31"),
        ("08:31", "Enchanted Forest",  "GW", "2", false, nil),
    ].map { time, dest, toc, plat, delayed, delay in
        (time, dest, toc, OperatorColours.entry(for: toc).primary, plat, delayed, delay)
    }

    private let themes: [RowTheme] = [.trackline, .timeTile, .timePanel]

    var body: some View {
        ZStack {
            Color.clear
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    let theme = themes[i % themes.count]
                    ThemedRow(
                        time: row.0, destination: row.1, colour: row.3,
                        theme: theme, platform: row.4, isDelayed: row.5, delayText: row.6
                    )
                    .frame(height: 52)
                    if i < rows.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(Material.ultraThin)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(16)
        }
    }
}

private struct ThemedRow: View {
    let time: String
    let destination: String
    let colour: Color
    let theme: RowTheme
    let platform: String
    let isDelayed: Bool
    let delayText: String?

    var body: some View {
        HStack(spacing: 0) {
            // Left accent / time panel
            if theme == .trackline {
                colour.frame(width: 3)
            } else if theme == .timePanel {
                colour.frame(width: 56)
                    .overlay(Text(time).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white))
            }

            if theme == .timePanel {
                Spacer().frame(width: 8)
            } else {
                Group {
                    if theme == .timeTile {
                        Text(time)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(colour, in: RoundedRectangle(cornerRadius: 5))
                    } else {
                        Text(time)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                }
                .padding(.leading, theme == .trackline ? 10 : 12)
            }

            if theme != .timePanel { Spacer().frame(width: 10) }

            // Destination + optional delay
            VStack(alignment: .leading, spacing: 1) {
                Text(destination)
                    .font(.system(size: 14))
                    .lineLimit(1)
                if let delay = delayText {
                    Text(delay)
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Status + platform
            HStack(spacing: 6) {
                if !isDelayed {
                    Text("On time")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                }
                Text(platform)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(.darkGray), in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity)
        .background(theme == .boardWash ? colour.opacity(0.18) : Color.clear)
        .padding(.horizontal, theme == .trackline ? 0 : 4)
    }
}

// MARK: Favourites

private struct MockFavouriteItem {
    let crs: String
    let name: String
    let boardType: String   // "dep" | "arr" | "filter"
    let filterLabel: String?
    let trailingIcon: String
    // next service pill data
    let pillTime: String
    let pillDest: String
    let pillPlatform: String?
    let pillDelayed: Bool
    let pillExpected: String?
}

private struct FavouritesPreview: View {
    private let items: [MockFavouriteItem] = [
        MockFavouriteItem(
            crs: "ARE", name: "Arendelle", boardType: "dep",
            filterLabel: nil, trailingIcon: "arrow.up.right",
            pillTime: "08:22", pillDest: "North Mountain",
            pillPlatform: nil, pillDelayed: false, pillExpected: nil
        ),
        MockFavouriteItem(
            crs: "ICP", name: "Ice Palace", boardType: "dep",
            filterLabel: nil, trailingIcon: "arrow.up.right",
            pillTime: "08:07", pillDest: "Arendelle",
            pillPlatform: nil, pillDelayed: true, pillExpected: "08:14"
        ),
        MockFavouriteItem(
            crs: "ARE", name: "Arendelle", boardType: "filter",
            filterLabel: "From Weselton", trailingIcon: "arrow.right.arrow.left",
            pillTime: "08:31", pillDest: "Weselton Intl",
            pillPlatform: nil, pillDelayed: false, pillExpected: nil
        ),
    ]

    var body: some View {
        ZStack {
            Color.clear
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    MockFavouriteRow(item: item)
                    if i < items.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Material.ultraThin, in: RoundedRectangle(cornerRadius: 12))
            .padding(16)
        }
    }
}

private struct MockFavouriteRow: View {
    let item: MockFavouriteItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: CRS pill · name + type · trailing icon
            HStack(spacing: 8) {
                // CRS pill (or stacked filter pill)
                if item.boardType == "filter" {
                    VStack(spacing: 1) {
                        Text("WES")
                            .font(Theme.crsFont)
                            .foregroundStyle(Theme.brand)
                        Image(systemName: "arrow.down")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text(item.crs)
                            .font(Theme.crsFont)
                            .foregroundStyle(Theme.brand)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Theme.brandSubtle, in: RoundedRectangle(cornerRadius: 4))
                } else {
                    Text(item.crs)
                        .font(Theme.crsFont)
                        .foregroundStyle(Theme.brand)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.brandSubtle, in: RoundedRectangle(cornerRadius: 4))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.headline)
                    if let filter = item.filterLabel {
                        Text(filter)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.boardType == "dep" ? "Departures" : item.boardType == "arr" ? "Arrivals" : "Departures")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: item.trailingIcon)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Next service pill — matches NextServicePillView exactly
            HStack(spacing: 5) {
                Text(item.pillTime)
                    .font(.system(.caption2, design: .monospaced).bold())
                Text(item.pillDest)
                    .font(.caption2)
                    .lineLimit(1)
                if item.pillDelayed {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Spacer(minLength: 0)
                if item.pillDelayed, let exp = item.pillExpected {
                    Text(exp)
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(.orange)
                }
                if let plat = item.pillPlatform {
                    Text("Plat \(plat)")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(white: 0.2), in: RoundedRectangle(cornerRadius: 3))
                        .environment(\.colorScheme, .dark)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.brandSubtle, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: Travel mode

private struct TravelModePreview: View {

    private let nowRows: [(String, String)] = [
        ("08:14", "North Mountain"),
        ("08:22", "Weselton Intl"),
        ("08:31", "Enchanted Forest"),
        ("08:45", "Ahtohallan"),
    ]
    private let laterRows: [(String, String)] = [
        ("09:18", "Ice Palace"),
        ("09:27", "Troll Valley"),
        ("09:34", "Oaken's Halt"),
        ("09:52", "Southern Isles"),
    ]

    var body: some View {
        ZStack {
            Color.clear
            HStack(alignment: .top, spacing: 10) {
                boardColumn(label: "Now", rows: nowRows)
                    .frame(maxWidth: .infinity)

                VStack {
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.brand)
                    Spacer()
                }
                .frame(width: 28)

                boardColumn(label: "+ 1 hour", rows: laterRows)
                    .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
    }

    private func boardColumn(label: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.brand, in: RoundedRectangle(cornerRadius: 6))
                .padding(.bottom, 8)

            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                HStack(spacing: 6) {
                    Text(row.0)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Text(row.1)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 6)
                if i < rows.count - 1 {
                    Divider()
                }
            }
        }
        .padding(10)
        .background(Material.ultraThin, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: Service detail

private struct ServiceDetailPreview: View {
    private struct Stop {
        let time: String
        let name: String
        let state: TimelineState
        var isCurrent: Bool = false
    }

    private let stops: [Stop] = [
        Stop(time: "07:30", name: "Arendelle",              state: .past),
        Stop(time: "07:51", name: "Valley of the Trolls",   state: .past),
        Stop(time: "08:09", name: "Oaken's Trading Post",   state: .current, isCurrent: true),
        Stop(time: "08:28", name: "The North Mountain",     state: .future),
        Stop(time: "08:47", name: "The Enchanted Forest",   state: .future),
        Stop(time: "09:10", name: "Ahtohallan",             state: .future),
    ]

    var body: some View {
        ZStack {
            Color.clear
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(stops.enumerated()), id: \.offset) { i, stop in

                        HStack(alignment: .center, spacing: 8) {
                            Text(stop.time)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(stop.state == .future ? .secondary : .primary)
                                .frame(width: 40, alignment: .trailing)

                            MiniTimelineIndicator(
                                position: i == 0 ? .first : (i == stops.count - 1 ? .last : .middle),
                                state: stop.state,
                                isCurrent: stop.isCurrent
                            )

                            Text(stop.name)
                                .font(.system(size: 13))
                                .foregroundStyle(stop.state == .future ? .secondary : .primary)
                                .fontWeight(stop.isCurrent ? .semibold : .regular)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 36)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .scrollContentBackground(.hidden)
            .background(Material.ultraThin, in: RoundedRectangle(cornerRadius: 12))
            .padding(16)
        }
    }
}

private struct MiniTimelineIndicator: View {
    let position: TimelinePosition
    let state: TimelineState
    var isCurrent: Bool = false

    private let size: CGFloat = 12
    private let lineW: CGFloat = 2

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(position == .first ? Color.clear : lineColor(top: true))
                    .frame(width: lineW)
                    .frame(maxHeight: .infinity)
                Rectangle()
                    .fill(position == .last ? Color.clear : lineColor(top: false))
                    .frame(width: lineW)
                    .frame(maxHeight: .infinity)
            }
            circle
        }
        .frame(width: 20)
    }

    private func lineColor(top: Bool) -> Color {
        switch state {
        case .past: return Theme.brand
        case .current: return top ? Theme.brand : Color.secondary.opacity(0.3)
        default: return Color.secondary.opacity(0.3)
        }
    }

    @ViewBuilder private var circle: some View {
        if isCurrent {
            Circle()
                .fill(Theme.brand)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
        } else if state == .past {
            Circle().fill(Theme.brand).frame(width: size, height: size)
        } else {
            Circle().stroke(Color.secondary.opacity(0.4), lineWidth: lineW).frame(width: size, height: size)
        }
    }
}

// MARK: Station info

private struct StationInfoPreview: View {
    private let facilities: [(String, String, Bool)] = [
        ("ticket.fill",        "Ticket Office",      true),
        ("figure.roll",        "Step-free Access",   true),
        ("car.fill",           "Car Park",           true),
        ("tram.fill",          "Underground",        false),
        ("fork.knife",         "Café",               true),
        ("bag.fill",           "Left Luggage",       false),
    ]

    var body: some View {
        ZStack {
            Color.clear
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(Theme.brand)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Arendelle Castle")
                            .font(.subheadline.bold())
                        Text("Managed by Avanti West Coast")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(facilities, id: \.0) { fac in
                        VStack(spacing: 4) {
                            Image(systemName: fac.0)
                                .font(.title3)
                                .foregroundStyle(fac.2 ? Theme.brand : Color(.tertiaryLabel))
                            Text(fac.1)
                                .font(.system(size: 9))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(fac.2 ? .primary : Color(.tertiaryLabel))
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Material.ultraThin, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .background(Material.ultraThin, in: RoundedRectangle(cornerRadius: 12))
            .padding(16)
        }
    }
}

// MARK: Auto-load & Shortcuts

private struct AutoloadPreview: View {
    @State private var step = 0

    var body: some View {
        ZStack {
            Color.clear
            VStack(spacing: 14) {
                // Flow diagram
                VStack(spacing: 0) {
                    FlowStep(icon: "location.fill", label: "You arrive near a station", color: Theme.brand, isActive: step >= 0)
                    FlowArrow(isActive: step >= 1)
                    FlowStep(icon: "star.fill", label: "App finds your nearest favourite", color: .yellow, isActive: step >= 1)
                    FlowArrow(isActive: step >= 2)
                    FlowStep(icon: "train.side.front.car", label: "Board opens automatically", color: .green, isActive: step >= 2)
                }

                // Shortcuts pill
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.brand)
                    Text("departure://departures/WAT")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Material.ultraThin, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .onAppear {
            animateSteps()
        }
    }

    private func animateSteps() {
        step = 0
        Task {
            while true {
                try? await Task.sleep(for: .seconds(1))
                withAnimation(.spring(duration: 0.4)) { if step < 2 { step += 1 } }
                if step == 2 {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation { step = 0 }
                }
            }
        }
    }
}

private struct FlowStep: View {
    let icon: String
    let label: String
    let color: Color
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(isActive ? color : Color(.tertiaryLabel))
                .frame(width: 28)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(isActive ? .primary : Color(.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Material.ultraThin, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .animation(.spring(duration: 0.4), value: isActive)
    }
}

private struct FlowArrow: View {
    let isActive: Bool

    var body: some View {
        Image(systemName: "chevron.down")
            .font(.caption.bold())
            .foregroundStyle(isActive ? Theme.brand : Color(.tertiaryLabel))
            .padding(.vertical, 2)
            .animation(.spring(duration: 0.4), value: isActive)
    }
}

// MARK: All features

private struct AllFeaturesPreview: View {

    private struct Feature {
        let icon: String
        let title: String
        let description: String
    }

    private let features: [Feature] = [
        Feature(icon: "rectangle.stack.fill",       title: "Home Screen Widgets",         description: "Small, medium & large. Single or dual station."),
        Feature(icon: "sparkles",                   title: "Split-Flap Animation",        description: "Vintage board effect on every refresh."),
        Feature(icon: "paintpalette.fill",           title: "Operator Livery Colours",     description: "7 row themes with authentic TOC colours."),
        Feature(icon: "clock.arrow.circlepath",      title: "Earlier & Later Trains",      description: "Browse any board forward or back in time."),
        Feature(icon: "list.bullet.rectangle.fill",  title: "Full Service Details",        description: "Every calling point, live delays & formation."),
        Feature(icon: "clock.fill",                 title: "Next Service on Favourites",  description: "See your next train without opening the board."),
        Feature(icon: "star.fill",                  title: "Unlimited Favourites",        description: "No cap on starred stations or filtered boards."),
        Feature(icon: "location.fill",              title: "Unlimited Nearby Stations",   description: "Show as many nearby stations as you like."),
        Feature(icon: "bolt.fill",                  title: "Smart Auto-Load",             description: "Opens your nearest favourite automatically."),
        Feature(icon: "building.2.fill",            title: "Station Information",         description: "Hours, facilities, accessibility & more."),
        Feature(icon: "arrow.up.doc.fill",          title: "Favourites Backup",           description: "Export & import your boards as JSON."),
        Feature(icon: "link",                       title: "URL Schemes & Shortcuts",     description: "Deep links and full Shortcuts app support."),
    ]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color.clear
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(features, id: \.title) { feature in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: feature.icon)
                                .font(.subheadline)
                                .foregroundStyle(Theme.brand)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feature.title)
                                    .font(.caption.bold())
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(feature.description)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Material.ultraThin, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(14)
            }
            .scrollContentBackground(.hidden)
        }
    }
}
