//
//  StationInfoView.swift
//  Departure Board
//
//  Created by Daniel Breslan on 13/02/2026.
//

import SwiftUI
import MapKit

struct StationInfoView: View {

    let crs: String
    let onDismiss: () -> Void

    @State private var info: StationInfo?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @AppStorage("mapsProvider") private var mapsProvider: String = "apple"

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else if let info {
                    stationInfoList(info)
                }
            }
            .navigationTitle(info?.Name ?? crs)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                }
            }
        }
        .task {
            await loadInfo()
        }
    }

    private func stationInfoList(_ info: StationInfo) -> some View {
        List {
            Group {
            // Map
            if let lat = Double(info.Latitude ?? ""),
               let lon = Double(info.Longitude ?? "") {
                Section {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    ))) {
                        Marker(info.Name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                    }
                    .frame(height: 180)
                    .listRowInsets(EdgeInsets())
                    .onTapGesture {
                        openInMaps(name: info.Name, lat: lat, lon: lon)
                    }
                }
            }

            // Alerts
            if let alerts = info.StationAlerts?.AlertText?.texts, !alerts.isEmpty {
                Section {
                    ForEach(alerts, id: \.self) { alert in
                        Text(stripHTML(alert))
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Label("Alerts", systemImage: "exclamationmark.triangle.fill")
                }
            }

            // General
            Section {
                if let op = info.StationOperator {
                    LabeledContent("Operator", value: op)
                }

                LabeledContent("CRS Code", value: info.CrsCode)

                if let address = formattedAddress(info) {
                    if let lat = Double(info.Latitude ?? ""),
                       let lon = Double(info.Longitude ?? "") {
                        Button {
                            openInMaps(name: info.Name, lat: lat, lon: lon)
                        } label: {
                            LabeledContent("Address") {
                                Text(address)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    } else {
                        LabeledContent("Address") {
                            Text(address)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                if let staffing = info.Staffing?.StaffingLevel {
                    LabeledContent("Staffing", value: formatStaffing(staffing))
                }

                if info.Staffing?.ClosedCircuitTelevision?.Overall == "true" {
                    LabeledContent("CCTV", value: "Yes")
                }

                if let cis = info.InformationSystems {
                    if cis.departureScreens != nil {
                        LabeledContent("Departure Screens", value: cis.departureScreens == true ? "Yes" : "No")
                    }
                    if cis.arrivalScreens != nil {
                        LabeledContent("Arrival Screens", value: cis.arrivalScreens == true ? "Yes" : "No")
                    }
                    if cis.announcements != nil {
                        LabeledContent("Announcements", value: cis.announcements == true ? "Yes" : "No")
                    }
                }
            } header: {
                Label("Station", systemImage: "building.2")
            }

            // Customer Service
            if let note = info.PassengerServices?.CustomerService?.Annotation?.Note {
                let cleaned = stripHTML(note)
                if !cleaned.isEmpty {
                    Section {
                        if let phone = extractPhoneNumber(note),
                           let url = makePhoneURL(phone) {
                            Link(destination: url) {
                                LabeledContent("Phone", value: phone)
                            }
                        }
                        Text(cleaned)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Label("Customer Service", systemImage: "person.fill")
                    }
                }
            }

            // Left Luggage
            if let ll = info.PassengerServices?.LeftLuggage {
                Section {
                    serviceContactRows(service: ll)
                } header: {
                    Label("Left Luggage", systemImage: "bag")
                }
            }

            // Lost Property
            if let lp = info.PassengerServices?.LostProperty {
                Section {
                    serviceContactRows(service: lp)
                } header: {
                    Label("Lost Property", systemImage: "magnifyingglass")
                }
            }

            // Ticket Office
            if info.Fares?.TicketOffice != nil {
                Section {
                    if let locationNote = info.Fares?.TicketOffice?.Annotation?.Note {
                        let cleaned = stripHTML(locationNote)
                        if !cleaned.isEmpty {
                            Text(cleaned)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let advanceNote = info.Fares?.TicketOffice?.Open?.Annotation?.Note {
                        let cleaned = stripHTML(advanceNote)
                        if !cleaned.isEmpty {
                            Text(cleaned)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let ticketOffice = info.Fares?.TicketOffice?.Open?.DayAndTimeAvailability {
                        ForEach(Array(ticketOffice.items.enumerated()), id: \.offset) { _, entry in
                            if let days = entry.DayTypes?.description,
                               let hours = entry.OpeningHours?.formatted, !hours.isEmpty {
                                LabeledContent(days, value: hours)
                            }
                        }
                    }
                } header: {
                    Label("Ticket Office", systemImage: "ticket")
                }
            }

            // Facilities
            Section {
                facilityRow("Toilets", icon: "toilet", available: info.StationFacilities?.Toilets)
                facilityRow("WiFi", icon: "wifi", available: info.StationFacilities?.WiFi)
                facilityRow("Waiting Room", icon: "chair.lounge", available: info.StationFacilities?.WaitingRoom)
                facilityRow("Seated Area", icon: "sofa", available: info.StationFacilities?.SeatedArea)
                facilityRow("Shops", icon: "bag", available: info.StationFacilities?.Shops)
                facilityRow("Buffet / Food", icon: "fork.knife", available: info.StationFacilities?.StationBuffet)
                facilityRow("ATM", icon: "banknote", available: info.StationFacilities?.AtmMachine)
                facilityRow("Baby Change", icon: "figure.and.child.holdinghands", available: info.StationFacilities?.BabyChange)
                facilityRow("Showers", icon: "shower", available: info.StationFacilities?.Showers)
                facilityRow("Post Box", icon: "envelope", available: info.StationFacilities?.PostBox)
                facilityRow("Trolleys", icon: "cart", available: info.StationFacilities?.Trolleys)

                if let ticketMachine = info.Fares?.TicketMachine {
                    facilityRow("Ticket Machine", icon: "rectangle.and.hand.point.up.left", available: ticketMachine)
                }

                // First Class Lounge
                if let lounge = info.StationFacilities?.FirstClassLounge {
                    let hasNote = lounge.Annotation?.Note != nil
                    let hasHours = lounge.Open?.DayAndTimeAvailability != nil
                    if hasNote || hasHours {
                        DisclosureGroup {
                            if let note = lounge.Annotation?.Note {
                                Text(stripHTML(note))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let hours = lounge.Open?.DayAndTimeAvailability {
                                ForEach(Array(hours.items.enumerated()), id: \.offset) { _, entry in
                                    if let days = entry.DayTypes?.description,
                                       let time = entry.OpeningHours?.formatted, !time.isEmpty {
                                        LabeledContent(days, value: time)
                                            .font(.caption)
                                    }
                                }
                            }
                        } label: {
                            Label("First Class Lounge", systemImage: "crown")
                        }
                    } else {
                        Label("First Class Lounge", systemImage: "crown")
                    }
                }
            } header: {
                Label("Facilities", systemImage: "list.bullet")
            }

            } // end Group 1

            Group {
            // Accessibility
            Section {
                if let coverage = info.ImpairedAccess?.StepFreeAccess?.Coverage {
                    if let note = info.ImpairedAccess?.StepFreeAccess?.Annotation?.Note {
                        DisclosureGroup {
                            Text(stripHTML(note))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } label: {
                            LabeledContent("Step-Free Access", value: formatCoverage(coverage))
                        }
                    } else {
                        LabeledContent("Step-Free Access", value: formatCoverage(coverage))
                    }
                }

                if let gate = info.ImpairedAccess?.TicketGate {
                    if let comments = info.ImpairedAccess?.TicketGateComments?.Note {
                        DisclosureGroup {
                            Text(stripHTML(comments))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } label: {
                            LabeledContent("Ticket Gates", value: gate == "true" ? "Yes" : "No")
                        }
                    } else {
                        LabeledContent("Ticket Gates", value: gate == "true" ? "Yes" : "No")
                    }
                }

                if info.ImpairedAccess?.InductionLoop == "true" {
                    LabeledContent("Induction Loop", value: "Yes")
                }

                facilityRow("Wheelchair Available", icon: "figure.roll", available: info.ImpairedAccess?.WheelchairsAvailable)
                facilityRow("Ramp Access", icon: "arrow.up.right", available: info.ImpairedAccess?.RampForTrainAccess)
                facilityRow("Accessible Ticket Machines", icon: "rectangle.and.hand.point.up.left", available: info.ImpairedAccess?.AccessibleTicketMachines)
                facilityRow("Accessible Booking Counter", icon: "person.and.background.dotted", available: info.ImpairedAccess?.AccessibleBookingOfficeCounter)
                facilityRow("National Key Toilets", icon: "key", available: info.ImpairedAccess?.NationalKeyToilets)
                facilityRow("Mobility Set Down", icon: "car.side", available: info.ImpairedAccess?.ImpairedMobilitySetDown)
                facilityRow("Customer Help Points", icon: "questionmark.circle", available: info.ImpairedAccess?.CustomerHelpPoints)

                annotationRow("Accessible Taxis", icon: "car.side", annotation: info.ImpairedAccess?.AccessibleTaxis)
                annotationRow("Accessible Phones", icon: "phone", annotation: info.ImpairedAccess?.AccessiblePublicTelephones)

                // Staff Help
                if let staff = info.ImpairedAccess?.StaffHelpAvailable {
                    let hasNote = staff.Annotation?.Note != nil
                    let hasHours = staff.Open?.DayAndTimeAvailability != nil
                    if hasNote || hasHours {
                        DisclosureGroup {
                            if let note = staff.Annotation?.Note {
                                Text(stripHTML(note))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let hours = staff.Open?.DayAndTimeAvailability {
                                ForEach(Array(hours.items.enumerated()), id: \.offset) { _, entry in
                                    if let days = entry.DayTypes?.description,
                                       let time = entry.OpeningHours?.formatted, !time.isEmpty {
                                        LabeledContent(days, value: time)
                                            .font(.caption)
                                    }
                                }
                            }
                        } label: {
                            Label("Staff Assistance", systemImage: "person.fill.questionmark")
                        }
                    }
                }

                // Helpline
                if let helpline = info.ImpairedAccess?.Helpline {
                    let hasNote = helpline.Annotation?.Note != nil
                    let hasPhone = helpline.ContactDetails?.PrimaryTelephoneNumber?.TelNationalNumber != nil
                    let hasUrl = helpline.ContactDetails?.Url != nil
                    if hasNote || hasPhone || hasUrl {
                        DisclosureGroup {
                            if let note = helpline.Annotation?.Note {
                                Text(stripHTML(note))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let phone = helpline.ContactDetails?.PrimaryTelephoneNumber?.TelNationalNumber,
                               let url = makePhoneURL(phone) {
                                Link(destination: url) {
                                    LabeledContent("Phone", value: phone)
                                }
                                .font(.caption)
                            }
                            if let contactNote = helpline.ContactDetails?.Annotation?.Note {
                                Text(stripHTML(contactNote))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let website = helpline.ContactDetails?.Url,
                               let url = URL(string: website) {
                                Link(destination: url) {
                                    LabeledContent("Website") {
                                        Text(website)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                                .font(.caption)
                            }
                        } label: {
                            Label("Assisted Travel Helpline", systemImage: "phone.arrow.right")
                        }
                    }
                }
            } header: {
                Label("Accessibility", systemImage: "accessibility")
            }

            // Transport Links
            Section {
                facilityRow("Taxi Rank", icon: "car.side", available: info.Interchange?.TaxiRank)
                facilityRow("Bus Services", icon: "bus", available: info.Interchange?.BusServices)
                facilityRow("Metro / Underground", icon: "tram", available: info.Interchange?.MetroServices)
                facilityRow("Airport", icon: "airplane", available: info.Interchange?.Airport)
                facilityRow("Car Hire", icon: "car.rear", available: info.Interchange?.CarHire)
                facilityRow("Cycle Hire", icon: "bicycle", available: info.Interchange?.CycleHire)

                annotationRow("Rail Replacement", icon: "bus.doubledecker", annotation: info.Interchange?.RailReplacementServices)

                if info.Interchange?.CycleStorageAvailability == "true" {
                    let hasExtra = info.Interchange?.CycleStorageNote?.Note != nil || info.Interchange?.CycleStorageLocation != nil
                    if hasExtra {
                        DisclosureGroup {
                            if let location = info.Interchange?.CycleStorageLocation {
                                Text(stripHTML(location))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let note = info.Interchange?.CycleStorageNote?.Note {
                                Text(stripHTML(note))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } label: {
                            HStack {
                                Label("Cycle Storage", systemImage: "bicycle")
                                Spacer()
                                VStack(alignment: .trailing) {
                                    if let spaces = info.Interchange?.CycleStorageSpaces {
                                        Text("\(spaces) spaces")
                                    }
                                    if let type = info.Interchange?.CycleStorageType?.text {
                                        Text(type)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if info.Interchange?.CycleStorageSheltered == "yes" {
                                        Text("Sheltered")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if info.Interchange?.CycleStorageCctv == "true" {
                                        Text("CCTV")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } else {
                        HStack {
                            Label("Cycle Storage", systemImage: "bicycle")
                            Spacer()
                            VStack(alignment: .trailing) {
                                if let spaces = info.Interchange?.CycleStorageSpaces {
                                    Text("\(spaces) spaces")
                                }
                                if let type = info.Interchange?.CycleStorageType?.text {
                                    Text(type)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if info.Interchange?.CycleStorageSheltered == "yes" {
                                    Text("Sheltered")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let carParks = info.Interchange?.CarPark?.items {
                    ForEach(Array(carParks.enumerated()), id: \.offset) { _, carPark in
                        let hasExtra = carPark.ContactDetails?.Url != nil || carPark.ContactDetails?.PrimaryTelephoneNumber?.TelNationalNumber != nil || carPark.Open?.DayAndTimeAvailability != nil
                        if hasExtra {
                            DisclosureGroup {
                                if let op = carPark.Operator {
                                    LabeledContent("Operator", value: op)
                                        .font(.caption)
                                }
                                if let phone = carPark.ContactDetails?.PrimaryTelephoneNumber?.TelNationalNumber,
                                   let url = makePhoneURL(phone) {
                                    Link(destination: url) {
                                        LabeledContent("Phone", value: phone)
                                    }
                                    .font(.caption)
                                }
                                if let website = carPark.ContactDetails?.Url,
                                   let url = URL(string: website) {
                                    Link(destination: url) {
                                        LabeledContent("Website") {
                                            Text(website)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                    }
                                    .font(.caption)
                                }
                                if let hours = carPark.Open?.DayAndTimeAvailability {
                                    ForEach(Array(hours.items.enumerated()), id: \.offset) { _, entry in
                                        if let days = entry.DayTypes?.description,
                                           let time = entry.OpeningHours?.formatted, !time.isEmpty {
                                            LabeledContent(days, value: time)
                                                .font(.caption)
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Label("Car Park", systemImage: "car")
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        if let name = carPark.Name {
                                            Text(name)
                                        }
                                        if let spaces = carPark.Spaces {
                                            Text("\(spaces) spaces")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        } else {
                            HStack {
                                Label("Car Park", systemImage: "car")
                                Spacer()
                                VStack(alignment: .trailing) {
                                    if let name = carPark.Name {
                                        Text(name)
                                    }
                                    if let spaces = carPark.Spaces {
                                        Text("\(spaces) spaces")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            } header: {
                Label("Transport Links", systemImage: "arrow.triangle.branch")
            }

            // Fares Info
            Section {
                if let zone = info.Fares?.Travelcard?.TravelcardZone {
                    LabeledContent("Travelcard Zone", value: zone)
                }

                if info.Fares?.PrepurchaseCollection == "true" {
                    LabeledContent("Pre-purchase Collection", value: "Yes")
                }
                if info.Fares?.SmartcardIssued == "true" {
                    LabeledContent("Smartcard", value: "Yes")
                }
                if info.Fares?.OysterPrePay == "true" {
                    LabeledContent("Oyster", value: "Yes")
                }

                if let oysterTopup = info.Fares?.OysterTopup, oysterTopup == "true" {
                    LabeledContent("Oyster Top-up", value: "Yes")
                }
                if let oysterValidator = info.Fares?.OysterValidator, oysterValidator == "true" {
                    LabeledContent("Oyster Validator", value: "Yes")
                }
                if let smartcardTopup = info.Fares?.SmartcardTopup, smartcardTopup == "true" {
                    LabeledContent("Smartcard Top-up", value: "Yes")
                }
                if let comments = info.Fares?.SmartcardComments?.Note {
                    let cleaned = stripHTML(comments)
                    if !cleaned.isEmpty {
                        Text(cleaned)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let penalty = info.Fares?.PenaltyFares?.Note {
                    Text(stripHTML(penalty))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Fares", systemImage: "creditcard")
            }
            } // end Group 2
        }
        .tint(.primary)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func facilityRow(_ name: String, icon: String, available: AvailableField?) -> some View {
        if let field = available {
            if let note = field.noteText.map({ stripHTML($0) }), !note.isEmpty {
                DisclosureGroup {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } label: {
                    LabeledContent {
                        Image(systemName: field.isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(field.isAvailable ? .green : .secondary)
                    } label: {
                        Label(name, systemImage: icon)
                    }
                }
            } else {
                LabeledContent {
                    Image(systemName: field.isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(field.isAvailable ? .green : .secondary)
                } label: {
                    Label(name, systemImage: icon)
                }
            }
        }
    }

    @ViewBuilder
    private func annotationRow(_ name: String, icon: String, annotation: AnnotationContainer?) -> some View {
        if let note = annotation?.Annotation?.Note.map({ stripHTML($0) }), !note.isEmpty {
            DisclosureGroup {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } label: {
                Label(name, systemImage: icon)
            }
        }
    }

    @ViewBuilder
    private func serviceContactRows(service: ServiceContactInfo) -> some View {
        if let phone = service.ContactDetails?.PrimaryTelephoneNumber?.TelNationalNumber,
           let url = makePhoneURL(phone) {
            Link(destination: url) {
                LabeledContent("Phone", value: phone)
            }
        }

        if let website = service.ContactDetails?.Url,
           let url = URL(string: website) {
            Link(destination: url) {
                LabeledContent("Website") {
                    Text(website)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }

        if let hours = service.Open?.Annotation?.Note {
            let cleaned = stripHTML(hours)
            if !cleaned.isEmpty {
                Text(cleaned)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        if let availability = service.Open?.DayAndTimeAvailability {
            ForEach(Array(availability.items.enumerated()), id: \.offset) { _, entry in
                if let days = entry.DayTypes?.description,
                   let time = entry.OpeningHours?.formatted, !time.isEmpty {
                    LabeledContent(days, value: time)
                }
            }
        }
    }

    private func formattedAddress(_ info: StationInfo) -> String? {
        guard let address = info.Address?.PostalAddress?.A_5LineAddress else { return nil }
        var parts = address.Line?.lines ?? []
        if let postcode = address.PostCode {
            parts.append(postcode)
        }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    private func formatStaffing(_ level: String) -> String {
        switch level {
        case "fullTime": return "Full Time"
        case "partTime": return "Part Time"
        case "unstaffed": return "Unstaffed"
        default: return level.capitalized
        }
    }

    private func formatCoverage(_ coverage: String) -> String {
        switch coverage {
        case "wholeStation": return "Whole Station"
        case "partial": return "Partial"
        default: return coverage.capitalized
        }
    }

    private func stripHTML(_ html: String) -> String {
        var text = html
        // Decode HTML entities first
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        // Block-level elements to newlines
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</h[1-6]>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</li>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<li[^>]*>", with: "• ", options: .regularExpression)
        // Strip remaining tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Collapse multiple blank lines
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractPhoneNumber(_ html: String?) -> String? {
        guard let html else { return nil }
        let stripped = stripHTML(html)
        let pattern = #"[\d\s\(\)\+\-]{7,}"#
        guard let range = stripped.range(of: pattern, options: .regularExpression) else { return nil }
        let number = String(stripped[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return number.isEmpty ? nil : number
    }

    private func makePhoneURL(_ number: String) -> URL? {
        let digits = number.replacingOccurrences(of: "[^\\d+]", with: "", options: .regularExpression)
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:\(digits)")
    }

    private func openInMaps(name: String, lat: Double, lon: Double) {
        if mapsProvider == "google",
           let url = URL(string: "comgooglemaps://?q=\(lat),\(lon)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if mapsProvider == "google",
                  let url = URL(string: "https://www.google.com/maps?q=\(lat),\(lon)") {
            UIApplication.shared.open(url)
        } else {
            let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let url = URL(string: "maps:?q=\(encoded)&ll=\(lat),\(lon)")!
            UIApplication.shared.open(url)
        }
    }

    private func loadInfo() async {
        do {
            let result = try await StationViewModel().fetchStationInfo(crs: crs)
            info = result
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load station information"
        }
        isLoading = false
    }
}
