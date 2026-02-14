//
//  ServiceDetailView.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import SwiftUI

struct ServiceDetailView: View {

    let service: Service
    let boardType: BoardType
    @Binding var navigationPath: NavigationPath

    @State private var detail: ServiceDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var infoPanelExpanded = false
    @State private var stationInfoCrs: String?

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
                List {
                    infoPanel(detail)
                    callingPointsList(detail)
                }
                .refreshable {
                    await loadDetail()
                }
            }
        }
        .navigationTitle(navigationTitleText)
        .task {
            await loadDetail(showLoading: true)
        }
        .refreshable {
            await loadDetail(showLoading: false)
        }
        .sheet(item: $stationInfoCrs) { crs in
            StationInfoView(crs: crs) {
                stationInfoCrs = nil
            }
        }
    }

    private var navigationTitleText: String {
        let locationName = boardType == .arrivals
            ? service.origin.location.first?.locationName ?? "Unknown"
            : service.destination.location.first?.locationName ?? "Unknown"
        return "\(service.scheduled) \(locationName)"
    }
    
    // MARK: - Info Panel

    @ViewBuilder
    private func infoPanel(_ detail: ServiceDetail) -> some View {
        Section {
            if infoPanelExpanded {
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
        } header: {
            Button {
                withAnimation {
                    infoPanelExpanded.toggle()
                }
            } label: {
                HStack {
                    Label(detail.locationName, systemImage: "info.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(infoPanelExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Calling Points

    @ViewBuilder
    private func callingPointsList(_ detail: ServiceDetail) -> some View {
        Section {
            // Previous calling points
            if let previous = detail.previousCallingPoints?.callingPointList {
                ForEach(previous.flatMap(\.callingPoint)) { point in
                    let isPast = point.at != nil
                    callingPointRow(
                        point,
                        isCurrent: false,
                        isPast: isPast
                    )
                    .contextMenu {
                        callingPointContextMenu(crs: point.crs, name: point.locationName)
                    }
                }
            }

            // Current station
            currentStationRow(detail)
                .contextMenu {
                    callingPointContextMenu(crs: detail.crs, name: detail.locationName)
                }

            // Subsequent calling points
            if let subsequent = detail.subsequentCallingPoints?.callingPointList {
                ForEach(subsequent.flatMap(\.callingPoint)) { point in
                    callingPointRow(point, isCurrent: false, isPast: false)
                        .contextMenu {
                            callingPointContextMenu(crs: point.crs, name: point.locationName)
                        }
                }
            }
        } header: {
            Label("Calling Points", systemImage: "arrow.down")
        }
    }

    private func currentStationRow(_ detail: ServiceDetail) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "location.fill")
                .foregroundStyle(.blue)
                .frame(width: 20)
                .padding(.top, 2)

            Text(detail.sta ?? detail.std ?? "")
                .font(.subheadline)
                .bold()
                .frame(width: 45, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(detail.locationName)
                    .font(.body)
                    .bold()

                if let ata = detail.ata {
                    Text(ata == "On time" ? "Arrived on time" : "Arrived at \(ata)")
                        .font(.caption)
                        .foregroundStyle(ata == "On time" ? Color.primary : Color.orange)
                } else if let eta = detail.eta {
                    Text(eta == "On time" ? "On time" : "Expected at \(eta)")
                        .font(.caption)
                        .foregroundStyle(eta == "On time" ? Color.primary : Color.orange)
                }
            }

            Spacer()

            if let platform = detail.platform {
                Text("P\(platform)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listRowBackground(Color.blue.opacity(0.08))
    }

    private func callingPointRow(_ point: CallingPoint, isCurrent: Bool, isPast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isPast ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(point.cancelled ? .red : (isPast ? .green : .secondary))
                .frame(width: 20)
                .padding(.top, 2)

            Text(point.st)
                .font(.subheadline)
                .frame(width: 45, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(point.locationName)
                    .font(.body)
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

            Spacer()
        }
    }

    // MARK: - Helpers

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
