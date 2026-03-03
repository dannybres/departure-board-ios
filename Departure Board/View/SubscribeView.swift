//
//  SubscribeView.swift
//  Departure Board
//

import SwiftUI

// MARK: - Page model

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
    @State private var currentPage = 0

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
            icon: "paintpalette.fill",
            title: "Boards That Turn Heads",
            subtitle: "Choose from seven row styles and full operator livery colours. Your board, your look — from subtle to striking.",
            preview: AnyView(ThemePreview())
        ),
        PaywallPage(
            id: 2,
            icon: "star.leadinghalf.filled",
            title: "Your Stations, Unlimited",
            subtitle: "Star as many stations as you like and see your next departure right on the card — tap to jump straight to the service.",
            preview: AnyView(FavouritesPreview())
        ),
        PaywallPage(
            id: 3,
            icon: "clock.arrow.circlepath",
            title: "See Earlier & Later Trains",
            subtitle: "Jump forward or back in time on any board. Perfect for planning connections or checking if you've already missed the last train.",
            preview: AnyView(TravelModePreview())
        ),
        PaywallPage(
            id: 4,
            icon: "list.bullet.rectangle.fill",
            title: "Every Stop, Every Detail",
            subtitle: "The full calling-point timeline with live delays at each stop, plus carriage formation and live loading percentages where available.",
            preview: AnyView(ServiceDetailPreview())
        ),
        PaywallPage(
            id: 5,
            icon: "building.2.fill",
            title: "Know Your Station",
            subtitle: "Ticket office hours, accessibility facilities, car parking, toilets, left luggage, and more — all in one place.",
            preview: AnyView(StationInfoPreview())
        ),
        PaywallPage(
            id: 6,
            icon: "bolt.fill",
            title: "Opens the Right Board, Automatically",
            subtitle: "The app opens your nearest favourite board the moment you arrive at a station. Hook it into Shortcuts for full automation.",
            preview: AnyView(AutoloadPreview())
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            carousel
            bottomBar
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .bottom)
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
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Feature previews

// MARK: Widgets

private struct WidgetPreview: View {
    var body: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            VStack(spacing: 10) {
                // Medium widget mock
                MockWidget(station: "London Waterloo", rows: [
                    ("07:42", "Reading", "On time", "4"),
                    ("07:55", "Southampton C", "On time", "6"),
                    ("08:03", "Basingstoke", "Delayed", "3"),
                    ("08:17", "Windsor", "On time", "1"),
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
            Color.black
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
    private let rows: [(String, String, String, Color)] = [
        ("08:14", "Edinburgh", "GR"),
        ("08:22", "Manchester", "TP"),
        ("08:31", "Bristol", "GW"),
        ("08:45", "Birmingham", "VT"),
    ].map { time, dest, toc in
        (time, dest, toc, OperatorColours.entry(for: toc).primary)
    }

    @State private var phase = 0
    private let themes: [RowTheme] = [.trackline, .timeTile, .timePanel, .boardWash, .platformPulse]

    var body: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    let theme = themes[i % themes.count]
                    ThemedRow(time: row.0, destination: row.1, colour: row.3, theme: theme)
                        .frame(height: 48)
                    if i < rows.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(Color(.systemBackground))
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

    var body: some View {
        HStack(spacing: 0) {
            // Left accent
            if theme == .trackline {
                colour.frame(width: 3)
            } else if theme == .timePanel {
                colour.frame(width: 56)
                    .overlay(Text(time).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white))
            }

            if theme == .timePanel {
                Spacer().frame(width: 8)
            } else {
                // Time tile or plain
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

            if theme != .timePanel {
                Spacer().frame(width: 10)
            }

            Text(destination)
                .font(.system(size: 14))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(theme == .boardWash ? colour.opacity(0.18) : Color.clear)
        .padding(.horizontal, theme == .trackline ? 0 : 4)
    }
}

// MARK: Favourites

private struct FavouritesPreview: View {
    private let items: [(String, String, String, Bool)] = [
        ("London Waterloo", "DEP", "08:22", false),
        ("Clapham Junction", "DEP", "08:07", true),
        ("Vauxhall", "ARR", "08:15", false),
    ]

    var body: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            VStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.0)
                                .font(.subheadline.bold())
                            Text(item.1 == "DEP" ? "Departures" : "Arrivals")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if item.2 != "" {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(item.2)
                                    .font(.caption.bold())
                            }
                            .foregroundStyle(item.3 ? .orange : Theme.brand)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background((item.3 ? Color.orange : Theme.brand).opacity(0.12), in: Capsule())
                        }
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                            .padding(.leading, 6)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(16)
        }
    }
}

// MARK: Travel mode

private struct TravelModePreview: View {
    @State private var selected = 1

    private let offsets = [
        (0, "Now"),
        (1, "+30 min"),
        (2, "+1 hour"),
        (3, "+2 hours"),
    ]

    var body: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("LONDON PADDINGTON")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.brand)
                    Text("Departures from \(offsets[selected].1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .animation(.default, value: selected)
                }

                // Offset selector
                HStack(spacing: 0) {
                    ForEach(offsets, id: \.0) { offset in
                        Button {
                            withAnimation(.spring(duration: 0.3)) { selected = offset.0 }
                        } label: {
                            Text(offset.1)
                                .font(.caption.bold())
                                .foregroundStyle(selected == offset.0 ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selected == offset.0 ? Theme.brand : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 20)

                // Mock services at selected offset
                VStack(spacing: 0) {
                    ForEach(mockRows(for: selected), id: \.0) { row in
                        HStack {
                            Text(row.0)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .frame(width: 44, alignment: .leading)
                            Text(row.1)
                                .font(.system(size: 13))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Plat \(row.2)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 14)
                    }
                }
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
            }
        }
    }

    private func mockRows(for offset: Int) -> [(String, String, String)] {
        let bases: [[(String, String, String)]] = [
            [("07:58","Reading","4"), ("08:12","Bristol Pkwy","1"), ("08:19","Oxford","3")],
            [("08:32","Swindon","2"), ("08:41","Cardiff C","5"), ("08:55","Bath Spa","1")],
            [("09:05","Exeter","3"), ("09:18","Didcot","4"), ("09:30","Bristol","2")],
            [("10:02","Plymouth","1"), ("10:15","Taunton","3"), ("10:28","Penzance","6")],
        ]
        return bases[min(offset, bases.count - 1)]
    }
}

// MARK: Service detail

private struct ServiceDetailPreview: View {
    private struct Stop {
        let time: String
        let name: String
        let state: TimelineState
        let platform: String?
        var isCurrent: Bool = false
    }

    private let stops: [Stop] = [
        Stop(time: "07:30", name: "London Waterloo", state: .past, platform: "10"),
        Stop(time: "07:44", name: "Clapham Junction", state: .past, platform: "2"),
        Stop(time: "08:01", name: "Woking", state: .current, platform: "3", isCurrent: true),
        Stop(time: "08:23", name: "Basingstoke", state: .future, platform: nil),
        Stop(time: "08:52", name: "Winchester", state: .future, platform: nil),
        Stop(time: "09:14", name: "Southampton C", state: .future, platform: "4"),
    ]

    var body: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(stops.enumerated()), id: \.offset) { i, stop in
                        HStack(alignment: .center, spacing: 8) {
                            // Time
                            Text(stop.time)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(stop.state == .future ? .secondary : .primary)
                                .frame(width: 40, alignment: .trailing)

                            // Timeline
                            MiniTimelineIndicator(
                                position: i == 0 ? .first : (i == stops.count - 1 ? .last : .middle),
                                state: stop.state,
                                isCurrent: stop.isCurrent
                            )

                            // Station name
                            Text(stop.name)
                                .font(.system(size: 13))
                                .foregroundStyle(stop.state == .future ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fontWeight(stop.isCurrent ? .semibold : .regular)

                            // Platform
                            if let plat = stop.platform {
                                Text(plat)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color(.darkGray), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .frame(height: 36)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
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
            Color(.secondarySystemGroupedBackground)
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(Theme.brand)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Manchester Piccadilly")
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
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(16)
        }
    }
}

// MARK: Auto-load & Shortcuts

private struct AutoloadPreview: View {
    @State private var step = 0

    var body: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
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
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
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
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
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
