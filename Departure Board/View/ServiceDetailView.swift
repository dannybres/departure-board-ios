//
//  ServiceDetailView.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import SwiftUI
import MapKit

// MARK: - Timeline Types

enum TimelinePosition {
    case first, middle, last
}

enum TimelineState {
    case past, current, future, cancelled
}

struct TimelineIndicator: View {
    let position: TimelinePosition
    let state: TimelineState
    private let circleSize: CGFloat = 20
    private let lineWidth: CGFloat = 2
    private let columnWidth: CGFloat = 30

    var body: some View {
        ZStack {
            // Vertical line segments
            VStack(spacing: 0) {
                // Top segment
                Rectangle()
                    .fill(position == .first ? Color.clear : topLineColor)
                    .frame(width: lineWidth)
                    .frame(maxHeight: .infinity)

                // Bottom segment
                Rectangle()
                    .fill(position == .last ? Color.clear : bottomLineColor)
                    .frame(width: lineWidth)
                    .frame(maxHeight: .infinity)
            }

            // Circle
            circleView


        }
        .frame(width: columnWidth)
    }

    private var topLineColor: Color {
        switch state {
        case .past:
            return Theme.brand
        case .current, .future, .cancelled:
            return Color.secondary.opacity(0.3)
        }
    }

    private var bottomLineColor: Color {
        switch state {
        case .past:
            return Theme.brand
        case .current, .future, .cancelled:
            return Color.secondary.opacity(0.3)
        }
    }

    @ViewBuilder
    private var circleView: some View {
        switch state {
        case .past:
            Circle()
                .fill(Theme.brand)
                .frame(width: circleSize, height: circleSize)
        case .current:
            ZStack {
                Circle()
                    .strokeBorder(Theme.brand, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .frame(width: circleSize + 4, height: circleSize + 4)
                Image(systemName: "location.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.brand.opacity(0.8))
            }
        case .future:
            Circle()
                .strokeBorder(Theme.brand, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                .frame(width: circleSize, height: circleSize)
        case .cancelled:
            ZStack {
                Circle()
                    .fill(.red)
                    .frame(width: circleSize, height: circleSize)
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - ServiceDetailView

struct ServiceDetailView: View {

    let service: Service
    let boardType: BoardType
    @Binding var navigationPath: NavigationPath

    @State private var detail: ServiceDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var stationInfoCrs: String?
    @State private var showInfoSheet = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detail {
                ScrollViewReader { proxy in
                    List {
                        callingPointsList(detail)
                    }
                    .refreshable {
                        await loadDetail()
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                proxy.scrollTo("currentStation", anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(navigationTitleText)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if detail != nil {
                    Button {
                        showInfoSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        .task {
            await loadDetail(showLoading: true)
        }
        .refreshable {
            await loadDetail(showLoading: false)
        }
        .sheet(item: $stationInfoCrs) { crs in
            StationInfoView(crs: crs, onDismiss: {
                stationInfoCrs = nil
            }, onNavigate: { boardType in
                if let station = StationCache.load()?.first(where: { $0.crsCode == crs }) {
                    stationInfoCrs = nil
                    navigationPath.append(StationDestination(station: station, boardType: boardType))
                }
            })
        }
        .sheet(isPresented: $showInfoSheet) {
            if let detail {
                infoSheet(detail)
            }
        }
    }

    private var navigationTitleText: String {
        let locationName = boardType == .arrivals
            ? service.origin.location.first?.locationName ?? "Unknown"
            : service.destination.location.first?.locationName ?? "Unknown"
        return "\(service.scheduled) \(locationName)"
    }

    // MARK: - Info Sheet

    private func infoSheet(_ detail: ServiceDetail) -> some View {
        NavigationStack {
            List {
                routeMapSection(detail)

                Section {
                    LabeledContent("Operator", value: detail.operator)

                    if let platform = detail.platform {
                        LabeledContent("Platform", value: platform)
                    }

                    if let length = detail.length {
                        LabeledContent("Coaches", value: length)
                    }

                    if let sta = detail.sta {
                        HStack {
                            Text("Arrival")
                            Spacer()
                            Text(sta)
                            if let ata = detail.ata {
                                Text("(\(ata))")
                                    .foregroundStyle(timeColor(scheduled: sta, actual: ata))
                            } else if let eta = detail.eta {
                                Text("(\(eta))")
                                    .foregroundStyle(timeColor(scheduled: sta, actual: eta))
                            }
                        }
                    }

                    if let std = detail.std {
                        HStack {
                            Text("Departure")
                            Spacer()
                            Text(std)
                            if let atd = detail.atd {
                                Text("(\(atd))")
                                    .foregroundStyle(timeColor(scheduled: std, actual: atd))
                            } else if let etd = detail.etd {
                                Text("(\(etd))")
                                    .foregroundStyle(timeColor(scheduled: std, actual: etd))
                            }
                        }
                    }

                    if let reason = detail.delayReason {
                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }

                    if let overdue = detail.overdueMessage {
                        Text(overdue)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(detail.locationName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showInfoSheet = false }
                }
            }
        }
    }

    // MARK: - Route Map

    @ViewBuilder
    private func routeMapSection(_ detail: ServiceDetail) -> some View {
        let stations = StationCache.load() ?? []
        let allPoints = routePoints(detail)
        let coordinates: [(CLLocationCoordinate2D, String, TimelineState)] = allPoints.compactMap { point in
            guard let station = stations.first(where: { $0.crsCode == point.crs }) else { return nil }
            return (CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude), point.name, point.state)
        }

        if coordinates.count >= 2 {
            Section {
                Map {
                    ForEach(Array(coordinates.enumerated()), id: \.offset) { _, item in
                        Marker(item.1, systemImage: "tram.fill", coordinate: item.0)
                            .tint(markerColor(for: item.2))
                    }
                    MapPolyline(coordinates: coordinates.map(\.0))
                        .stroke(Theme.brand, lineWidth: 3)
                }
                .frame(height: 220)
                .listRowInsets(EdgeInsets())
            }
        }
    }

    private struct RoutePoint {
        let crs: String
        let name: String
        let state: TimelineState
    }

    private func routePoints(_ detail: ServiceDetail) -> [RoutePoint] {
        var points: [RoutePoint] = []

        if let previous = detail.previousCallingPoints?.callingPointList {
            for point in previous.flatMap(\.callingPoint) {
                let state: TimelineState = point.cancelled ? .cancelled : (point.at != nil ? .past : .future)
                points.append(RoutePoint(crs: point.crs, name: point.locationName, state: state))
            }
        }

        points.append(RoutePoint(crs: detail.crs, name: detail.locationName, state: .current))

        if let subsequent = detail.subsequentCallingPoints?.callingPointList {
            for point in subsequent.flatMap(\.callingPoint) {
                let state: TimelineState = point.cancelled ? .cancelled : .future
                points.append(RoutePoint(crs: point.crs, name: point.locationName, state: state))
            }
        }

        return points
    }

    private func markerColor(for state: TimelineState) -> Color {
        switch state {
        case .past: return .green
        case .current: return Theme.brand
        case .future: return .secondary
        case .cancelled: return .red
        }
    }

    // MARK: - Calling Points (Timeline)

    @ViewBuilder
    private func callingPointsList(_ detail: ServiceDetail) -> some View {
        Section {
            let allPoints = buildTimelineRows(detail)
            ForEach(Array(allPoints.enumerated()), id: \.offset) { index, row in
                let position: TimelinePosition = index == 0 ? .first : (index == allPoints.count - 1 ? .last : .middle)

                switch row {
                case .previous(let point):
                    let isPast = point.at != nil
                    let state: TimelineState = point.cancelled ? .cancelled : (isPast ? .past : .future)
                    timelineRow(position: position, state: state) {
                        callingPointContent(point, isPast: isPast)
                    }
                    .contextMenu {
                        callingPointContextMenu(crs: point.crs, name: point.locationName)
                    }

                case .current(let d):
                    timelineRow(position: position, state: .current) {
                        currentStationContent(d)
                    }
                    .id("currentStation")
                    .contextMenu {
                        callingPointContextMenu(crs: d.crs, name: d.locationName)
                    }

                case .subsequent(let point):
                    let state: TimelineState = point.cancelled ? .cancelled : .future
                    timelineRow(position: position, state: state) {
                        callingPointContent(point, isPast: false)
                    }
                    .contextMenu {
                        callingPointContextMenu(crs: point.crs, name: point.locationName)
                    }
                }
            }
        } header: {
            Label("Calling Points", systemImage: "arrow.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.brand)
                .textCase(nil)
        }
    }

    private enum TimelineRow {
        case previous(CallingPoint)
        case current(ServiceDetail)
        case subsequent(CallingPoint)
    }

    private func buildTimelineRows(_ detail: ServiceDetail) -> [TimelineRow] {
        var rows: [TimelineRow] = []

        if let previous = detail.previousCallingPoints?.callingPointList {
            for point in previous.flatMap(\.callingPoint) {
                rows.append(.previous(point))
            }
        }

        rows.append(.current(detail))

        if let subsequent = detail.subsequentCallingPoints?.callingPointList {
            for point in subsequent.flatMap(\.callingPoint) {
                rows.append(.subsequent(point))
            }
        }

        return rows
    }

    private func timelineRow<Content: View>(position: TimelinePosition, state: TimelineState, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            TimelineIndicator(position: position, state: state)
                .padding(.vertical, -20)
                .frame(maxHeight: .infinity)

            content()
                .padding(.vertical, 4)

            Spacer()
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    private func currentStationContent(_ detail: ServiceDetail) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(detail.sta ?? detail.std ?? "")
                .font(.subheadline)
                .bold()
                .frame(width: 45, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(detail.locationName)
                    .font(.subheadline)
                    .bold()

                if let ata = detail.ata {
                    Text(ata == "On time" ? "Arrived on time" : (isTimeFormat(ata) ? "Arrived at \(ata)" : ata))
                        .font(.caption)
                        .foregroundStyle(ata == "On time" ? Color.primary : Color.orange)
                } else if let eta = detail.eta {
                    Text(eta == "On time" ? "On time" : (isTimeFormat(eta) ? "Expected at \(eta)" : eta))
                        .font(.caption)
                        .foregroundStyle(eta == "On time" ? Color.primary : Color.orange)
                }
            }

            Spacer()

            if let platform = detail.platform {
                Text("Plat \(platform)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        colorScheme == .dark ? Theme.platformBadgeDark : Theme.platformBadge,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
            }
        }
    }

    private func callingPointContent(_ point: CallingPoint, isPast: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(point.st)
                .font(.subheadline)
                .frame(width: 45, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(point.locationName)
                    .font(.subheadline)
                    .strikethrough(point.cancelled)

                if point.cancelled {
                    Text(point.cancelReason ?? "Cancelled")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if point.status.lowercased() != "on time" && !point.status.isEmpty && point.status != "No report" {
                    if point.status.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil {
                        Text(isPast ? "Departed at \(point.status)" : "Expected at \(point.status)")
                            .font(.caption)
                            .foregroundStyle(point.isLate ? .orange : .primary)
                    } else {
                        Text(point.status)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if let reason = point.delayReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Helpers

    private func isTimeFormat(_ text: String) -> Bool {
        text.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil
    }

    private func timeColor(scheduled: String, actual: String) -> Color {
        let text = actual.lowercased()
        if text == "on time" { return .primary }
        if text.contains("cancel") || text.contains("delayed") { return .red }
        if actual.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil {
            return actual > scheduled ? .orange : .primary
        }
        return .primary
    }

    private func loadDetail(showLoading: Bool = false) async {
        if showLoading { isLoading = true }
        do {
            let result = try await StationViewModel().fetchServiceDetail(serviceID: service.serviceID)
            detail = result
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load service details"
        }
        isLoading = false
    }

    private func stationFromCache(crs: String, name: String) -> Station? {
        if let station = StationCache.load()?.first(where: { $0.crsCode == crs }) {
            return station
        }
        return nil
    }

    @ViewBuilder
    private func callingPointContextMenu(crs: String, name: String) -> some View {
        if let station = stationFromCache(crs: crs, name: name) {
            Button {
                navigationPath.append(StationDestination(station: station, boardType: .departures))
            } label: {
                Label("Show Departures", systemImage: "arrow.up.right")
            }

            Button {
                navigationPath.append(StationDestination(station: station, boardType: .arrivals))
            } label: {
                Label("Show Arrivals", systemImage: "arrow.down.left")
            }

            Divider()
        }

        Button {
            stationInfoCrs = crs
        } label: {
            Label("Station Information", systemImage: "info.circle")
        }
    }
}
