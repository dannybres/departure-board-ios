//
//  DepartureBoardView.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import SwiftUI

enum BoardType: String, CaseIterable {
    case departures
    case arrivals
}

struct DepartureBoardView: View {
    
    let station: Station
    var initialBoardType: BoardType = .departures

    // MARK: - State
    @State private var board: DepartureBoard?
    @State private var isLoading = true
    @State private var showInfo = false
    @State private var errorMessage: String?
    @State private var selectedBoard: BoardType = .departures

    init(station: Station, initialBoardType: BoardType = .departures) {
        self.station = station
        self.initialBoardType = initialBoardType
        _selectedBoard = State(initialValue: initialBoardType)
    }
    
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
            } else if let board {
                List {
                    if let services = board.trainServices?.service {
                        ForEach(services) { service in
                            NavigationLink(value: service) {
                                DepartureRow(service: service, boardType: selectedBoard)
                            }
                        }
                        
                        HStack {
                            Spacer()
                            Image("NRE")   // must match your asset name
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                                .opacity(0.6)
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    } else {
                        Text("No services available")
                            .foregroundStyle(.secondary)
                    }
                }
                .refreshable {
                    await loadBoard(type: selectedBoard)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            // Action here
                            showInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                }
                .sheet(isPresented: $showInfo) {
                    NavigationStack {
                        Text("Hello")
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") { showInfo = false }
                                }
                            }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, alignment: .leading) {
            Picker("Board Type", selection: $selectedBoard) {
                ForEach(BoardType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .padding()
        }
        .navigationTitle(station.name)
        .navigationDestination(for: Service.self) { service in
            ServiceDetailView(
                service: service,
                boardType: selectedBoard
            )
        }
        .onChange(of: selectedBoard) {
            Task {
                await loadBoard(type: selectedBoard, showLoading: true)
            }
        }
        .task {
            await loadBoard(type: selectedBoard, showLoading: true)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadBoard(type: BoardType, showLoading: Bool = false) async {
        if showLoading { isLoading = true }
        do {
            let result = try await StationViewModel().fetchBoard(for: station.crsCode, type: type)
            board = result
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load board"
        }
        isLoading = false
    }
}

// MARK: - Departure Row Subview

struct DepartureRow: View {

    let service: Service
    let boardType: BoardType

    private var location: Location? {
        if boardType == .arrivals {
            return service.origin.location.first
        }
        return service.destination.location.first
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(service.scheduled)
                .font(.title3)
                .bold()
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(location?.locationName ?? "")
                    .font(.headline)

                if let via = location?.via {
                    Text(via)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if service.estimated.lowercased() != "on time" {
                    Text(isTimeFormat(service.estimated) ? "Expected at \(service.estimated)" : service.estimated)
                        .font(.subheadline)
                        .foregroundStyle(statusColor(for: service.estimated))
                }

                if let platform = service.platform {
                    Text("Platform \(platform)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func isTimeFormat(_ text: String) -> Bool {
        text.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil
    }

    private func statusColor(for etd: String) -> Color {
        let text = etd.lowercased()
        if text.contains("cancel") { return .red }
        if text.contains("delayed") { return .red }
        if text.contains("on time") { return .primary }
        return .orange
    }
}
