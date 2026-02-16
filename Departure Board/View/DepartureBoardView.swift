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
    @Binding var navigationPath: NavigationPath

    // MARK: - State
    @State private var board: DepartureBoard?
    @State private var isLoading = true
    @State private var showInfo = false
    @State private var errorMessage: String?
    @State private var selectedBoard: BoardType = .departures

    init(station: Station, initialBoardType: BoardType = .departures, navigationPath: Binding<NavigationPath>) {
        self.station = station
        self.initialBoardType = initialBoardType
        self._navigationPath = navigationPath
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
                            Section {
                                NavigationLink(value: service) {
                                    DepartureRow(service: service, boardType: selectedBoard)
                                }
                            }
                        }

                        HStack {
                            Spacer()
                            Image("NRE")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                                .opacity(0.6)
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else {
                        Text("No services available")
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
                .listSectionSpacing(6)
                .refreshable {
                    await loadBoard(type: selectedBoard)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity
                ))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showInfo) {
            StationInfoView(crs: station.crsCode, onDismiss: {
                showInfo = false
            }, onNavigate: { boardType in
                showInfo = false
                selectedBoard = boardType
            })
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
                boardType: selectedBoard,
                navigationPath: $navigationPath
            )
        }
        .onChange(of: selectedBoard) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            withAnimation(.easeInOut(duration: 0.3)) {
                board = result
                errorMessage = nil
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = "Failed to load board"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        isLoading = false
    }
}

// MARK: - Departure Row Subview

struct DepartureRow: View {

    let service: Service
    let boardType: BoardType
    @Environment(\.colorScheme) private var colorScheme

    private var location: Location? {
        if boardType == .arrivals {
            return service.origin.location.first
        }
        return service.destination.location.first
    }

    private var isCancelled: Bool {
        service.estimated.lowercased().contains("cancel")
    }

    private var isDelayed: Bool {
        let text = service.estimated.lowercased()
        return text.contains("delayed") || (isTimeFormat(service.estimated) && service.estimated > service.scheduled)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(service.scheduled)
                .font(Theme.timeFont)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(location?.locationName ?? "")
                        .font(.title3.weight(.semibold))

                    if isCancelled {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    } else if isDelayed {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

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
            }

            Spacer()

            if let platform = service.platform {
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
        .padding(.vertical, Theme.rowPadding)
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
