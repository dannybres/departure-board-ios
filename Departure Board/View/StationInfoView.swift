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
    var onNavigate: ((BoardType) -> Void)? = nil

    @State private var info: StationInfo?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @AppStorage("mapsProvider") private var mapsProvider: String = "apple"

    private var cachedStation: Station? {
        StationCache.load()?.first(where: { $0.crsCode == crs })
    }

    var body: some View {
        NavigationStack {
            List {
                // Navigation buttons — available immediately
                if let onNavigate {
                    Section {
                        Button {
                            onNavigate(.departures)
                        } label: {
                            Label("Show Departures", systemImage: "arrow.up.right")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .tint(Theme.brand)

                        Button {
                            onNavigate(.arrivals)
                        } label: {
                            Label("Show Arrivals", systemImage: "arrow.down.left")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .tint(Theme.brand)
                    }
                }

                // Map — from cache immediately, upgraded with API data when available
                if let lat = mapLatitude, let lon = mapLongitude {
                    Section {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        ))) {
                            Marker(mapName, systemImage: "tram.fill", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                                .tint(Theme.brand)
                        }
                        .frame(height: 180)
                        .listRowInsets(EdgeInsets())
                        .onTapGesture {
                            openInMaps(name: mapName, lat: lat, lon: lon)
                        }
                    }
                }

                // Station section — CRS immediately, API details appended when loaded
                Section {
                    LabeledContent("CRS Code", value: crs)
                        .copyable(crs)

                    if let info {
                        if let op = info.stationOperator {
                            LabeledContent("Operator", value: op)
                                .copyable(op)
                        }

                        if let address = formattedAddress(info) {
                            if let lat = info.latitude,
                               let lon = info.longitude {
                                Button {
                                    openInMaps(name: info.name, lat: lat, lon: lon)
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
                                .copyable(address)
                            }
                        }

                        if let staffing = info.staffing?.staffingLevel {
                            LabeledContent("Staffing", value: formatStaffing(staffing))
                                .copyable(formatStaffing(staffing))
                        }

                        if info.staffing?.closedCircuitTelevision?.overall == true {
                            LabeledContent("CCTV", value: "Yes")
                        }
                    }
                } header: {
                    infoSectionHeader("Station", icon: "building.2")
                }

                // API-loaded content
                if let info {
                    stationInfoSections(info)
                } else if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .tint(.primary)
            .navigationTitle(info?.name ?? cachedStation?.name ?? crs)
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

    private var mapLatitude: Double? {
        if let info, let lat = info.latitude { return lat }
        return cachedStation?.latitude
    }

    private var mapLongitude: Double? {
        if let info, let lon = info.longitude { return lon }
        return cachedStation?.longitude
    }

    private var mapName: String {
        info?.name ?? cachedStation?.name ?? crs
    }

    @ViewBuilder
    private func stationInfoSections(_ info: StationInfo) -> some View {
            // Group 1: Alerts, InformationSystems, CustomerService
            Group {
            // Alerts
            if let alertText = info.stationAlerts?.alertText, !alertText.isEmpty {
                Section {
                    Text(richText(alertText))
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .copyable(stripHTML(alertText))
                        .listRowBackground(Color.red.opacity(0.08))
                } header: {
                    infoSectionHeader("Alerts", icon: "exclamationmark.triangle.fill")
                }
            }

            if info.informationSystems != nil {
                Section {
                    if let departures = info.informationSystems?.departureScreens {
                        LabeledContent("Departure Screens", value: departures ? "Yes" : "No")
                            .copyable(departures ? "Yes" : "No")
                    }
                    if let arrivals = info.informationSystems?.arrivalScreens {
                        LabeledContent("Arrival Screens", value: arrivals ? "Yes" : "No")
                            .copyable(arrivals ? "Yes" : "No")
                    }
                    if let announcements = info.informationSystems?.announcements {
                        LabeledContent("Announcements", value: announcements ? "Yes" : "No")
                            .copyable(announcements ? "Yes" : "No")
                    }
                } header: {
                    infoSectionHeader("Information Systems", icon: "tv")
                }
            }

            // Customer Service
            if let note = info.passengerServices?.customerService?.annotation?.note {
                let cleaned = stripHTML(note)
                if !cleaned.isEmpty {
                    Section {
                        if let phone = extractPhoneNumber(note),
                           let url = makePhoneURL(phone) {
                            Link(destination: url) {
                                LabeledContent("Phone", value: phone)
                            }
                            .copyable(phone)
                        }
                        Text(cleaned)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .copyable(cleaned)
                    } header: {
                        infoSectionHeader("Customer Service", icon: "person.fill")
                    }
                }
            }

            } // end Group 1

            // Group 2: LeftLuggage, LostProperty, TicketOffice, Facilities
            Group {
            // Left Luggage
            if let ll = info.passengerServices?.leftLuggage {
                Section {
                    serviceContactRows(service: ll)
                } header: {
                    infoSectionHeader("Left Luggage", icon: "bag")
                }
            }

            // Lost Property
            if let lp = info.passengerServices?.lostProperty {
                Section {
                    serviceContactRows(service: lp)
                } header: {
                    infoSectionHeader("Lost Property", icon: "magnifyingglass")
                }
            }

            // Ticket Office
            if info.fares?.ticketOffice != nil {
                Section {
                    if let locationNote = info.fares?.ticketOffice?.annotation?.note {
                        let cleaned = stripHTML(locationNote)
                        if !cleaned.isEmpty {
                            Text(cleaned)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .copyable(cleaned)
                        }
                    }

                    if let advanceNote = info.fares?.ticketOffice?.open?.annotation?.note {
                        let cleaned = stripHTML(advanceNote)
                        if !cleaned.isEmpty {
                            Text(cleaned)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .copyable(cleaned)
                        }
                    }

                    if let ticketOffice = info.fares?.ticketOffice?.open?.dayAndTimeAvailability {
                        ForEach(Array(ticketOffice.enumerated()), id: \.offset) { _, entry in
                            if let days = entry.dayTypes?.description,
                               let hours = entry.openingHours?.formatted, !hours.isEmpty {
                                LabeledContent(days, value: hours)
                                    .copyable(hours)
                            }
                        }
                    }
                } header: {
                    infoSectionHeader("Ticket Office", icon: "ticket")
                }
            }

            // Facilities
            Section {
                facilityRow("Toilets", icon: "toilet", available: info.stationFacilities?.toilets)
                facilityRow("WiFi", icon: "wifi", available: info.stationFacilities?.wiFi)
                facilityRow("Waiting Room", icon: "chair.lounge", available: info.stationFacilities?.waitingRoom)
                facilityRow("Seated Area", icon: "sofa", available: info.stationFacilities?.seatedArea)
                facilityRow("Shops", icon: "bag", available: info.stationFacilities?.shops)
                facilityRow("Buffet / Food", icon: "fork.knife", available: info.stationFacilities?.stationBuffet)
                facilityRow("ATM", icon: "banknote", available: info.stationFacilities?.atmMachine)
                facilityRow("Baby Change", icon: "figure.and.child.holdinghands", available: info.stationFacilities?.babyChange)
                facilityRow("Showers", icon: "shower", available: info.stationFacilities?.showers)
                facilityRow("Post Box", icon: "envelope", available: info.stationFacilities?.postBox)
                facilityRow("Trolleys", icon: "cart", available: info.stationFacilities?.trolleys)

                if let ticketMachine = info.fares?.ticketMachine {
                    facilityRow("Ticket Machine", icon: "rectangle.and.hand.point.up.left", available: ticketMachine)
                }

                // First Class Lounge
                if let lounge = info.stationFacilities?.firstClassLounge {
                    let hasNote = lounge.annotation?.note != nil
                    let hasHours = lounge.open?.dayAndTimeAvailability != nil
                    if hasNote || hasHours {
                        DisclosureGroup {
                            if let note = lounge.annotation?.note {
                                Text(richText(note))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let hours = lounge.open?.dayAndTimeAvailability {
                                ForEach(Array(hours.enumerated()), id: \.offset) { _, entry in
                                    if let days = entry.dayTypes?.description,
                                       let time = entry.openingHours?.formatted, !time.isEmpty {
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
                infoSectionHeader("Facilities", icon: "list.bullet")
            }

            } // end Group 2

            // Group 3: Accessibility, TransportLinks, Fares
            Group {
            // Accessibility
            Section {
                if let coverage = info.impairedAccess?.stepFreeAccess?.coverage {
                    if let note = info.impairedAccess?.stepFreeAccess?.annotation?.note {
                        DisclosureGroup {
                            Text(richText(note))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } label: {
                            LabeledContent("Step-Free Access", value: formatCoverage(coverage))
                        }
                    } else {
                        LabeledContent("Step-Free Access", value: formatCoverage(coverage))
                            .padding(.trailing, 20)
                            .copyable(formatCoverage(coverage))
                    }
                }

                if let gate = info.impairedAccess?.ticketGate {
                    if let comments = info.impairedAccess?.ticketGateComments?.note {
                        DisclosureGroup {
                            Text(richText(comments))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } label: {
                            LabeledContent("Ticket Gates", value: gate ? "Yes" : "No")
                        }
                    } else {
                        LabeledContent("Ticket Gates", value: gate ? "Yes" : "No")
                            .padding(.trailing, 20)
                    }
                }

                if info.impairedAccess?.inductionLoop == true {
                    LabeledContent("Induction Loop", value: "Yes")
                        .padding(.trailing, 20)
                }

                facilityRow("Wheelchair Available", icon: "figure.roll", available: info.impairedAccess?.wheelchairsAvailable)
                facilityRow("Ramp Access", icon: "arrow.up.right", available: info.impairedAccess?.rampForTrainAccess)
                facilityRow("Accessible Ticket Machines", icon: "rectangle.and.hand.point.up.left", available: info.impairedAccess?.accessibleTicketMachines)
                facilityRow("Accessible Booking Counter", icon: "person.and.background.dotted", available: info.impairedAccess?.accessibleBookingOfficeCounter)
                facilityRow("National Key Toilets", icon: "key", available: info.impairedAccess?.nationalKeyToilets)
                facilityRow("Mobility Set Down", icon: "car.side", available: info.impairedAccess?.impairedMobilitySetDown)
                facilityRow("Customer Help Points", icon: "questionmark.circle", available: info.impairedAccess?.customerHelpPoints)

                facilityRow("Accessible Taxis", icon: "car.side", available: info.impairedAccess?.accessibleTaxis)
                facilityRow("Accessible Phones", icon: "phone", available: info.impairedAccess?.accessiblePublicTelephones)

                // Staff Help
                if let staff = info.impairedAccess?.staffHelpAvailable {
                    let hasNote = staff.annotation?.note != nil
                    let hasHours = staff.open?.dayAndTimeAvailability != nil
                    if hasNote || hasHours {
                        DisclosureGroup {
                            if let note = staff.annotation?.note {
                                Text(richText(note))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let hours = staff.open?.dayAndTimeAvailability {
                                ForEach(Array(hours.enumerated()), id: \.offset) { _, entry in
                                    if let days = entry.dayTypes?.description,
                                       let time = entry.openingHours?.formatted, !time.isEmpty {
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
                if let helpline = info.impairedAccess?.helpline {
                    let hasNote = helpline.annotation?.note != nil
                    let hasPhone = helpline.contactDetails?.primaryTelephoneNumber?.telNationalNumber != nil
                    let hasUrl = helpline.contactDetails?.url != nil
                    if hasNote || hasPhone || hasUrl {
                        DisclosureGroup {
                            if let note = helpline.annotation?.note {
                                Text(richText(note))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let phone = helpline.contactDetails?.primaryTelephoneNumber?.telNationalNumber,
                               let url = makePhoneURL(phone) {
                                Link(destination: url) {
                                    LabeledContent("Phone", value: phone)
                                }
                                .font(.caption)
                                .copyable(phone)
                            }
                            if let contactNote = helpline.contactDetails?.annotation?.note {
                                Text(richText(contactNote))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .copyable(stripHTML(contactNote))
                            }
                            if let website = helpline.contactDetails?.url,
                               let url = URL(string: website) {
                                Link(destination: url) {
                                    LabeledContent("Website") {
                                        Text(website)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                                .font(.caption)
                                .copyable(website)
                            }
                        } label: {
                            Label("Assisted Travel Helpline", systemImage: "phone.arrow.right")
                        }
                    }
                }
            } header: {
                infoSectionHeader("Accessibility", icon: "accessibility")
            }

            // Transport Links
            Section {
                facilityRow("Taxi Rank", icon: "car.side", available: info.interchange?.taxiRank)
                facilityRow("Bus Services", icon: "bus", available: info.interchange?.busServices)
                facilityRow("Metro / Underground", icon: "tram", available: info.interchange?.metroServices)
                facilityRow("Airport", icon: "airplane", available: info.interchange?.airport)
                facilityRow("Car Hire", icon: "car.rear", available: info.interchange?.carHire)
                facilityRow("Cycle Hire", icon: "bicycle", available: info.interchange?.cycleHire)

                if let rrs = info.interchange?.railReplacementServices, let note = rrs.annotation?.note {
                    let cleaned = stripHTML(note)
                    if !cleaned.isEmpty {
                        DisclosureGroup {
                            Text(cleaned)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Rail Replacement", systemImage: "bus.doubledecker")
                        }
                    }
                }

                if info.interchange?.cycleStorageAvailability == true {
                    let hasExtra = info.interchange?.cycleStorageNote?.note != nil || info.interchange?.cycleStorageLocation != nil
                    if hasExtra {
                        DisclosureGroup {
                            if let location = info.interchange?.cycleStorageLocation {
                                Text(richText(location))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let note = info.interchange?.cycleStorageNote?.note {
                                Text(richText(note))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } label: {
                            HStack {
                                Label("Cycle Storage", systemImage: "bicycle")
                                Spacer()
                                VStack(alignment: .trailing) {
                                    if let spaces = info.interchange?.cycleStorageSpaces {
                                        Text("\(spaces) spaces")
                                    }
                                    if let types = info.interchange?.cycleStorageType {
                                        Text(types.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if info.interchange?.cycleStorageSheltered == true {
                                        Text("Sheltered")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if info.interchange?.cycleStorageCctv == true {
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
                                if let spaces = info.interchange?.cycleStorageSpaces {
                                    Text("\(spaces) spaces")
                                }
                                if let types = info.interchange?.cycleStorageType {
                                    Text(types.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if info.interchange?.cycleStorageSheltered == true {
                                    Text("Sheltered")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let carPark = info.interchange?.carPark {
                    let hasExtra = carPark.contactDetails?.url != nil || carPark.contactDetails?.primaryTelephoneNumber?.telNationalNumber != nil || carPark.open?.dayAndTimeAvailability != nil
                    if hasExtra {
                        DisclosureGroup {
                            if let op = carPark.carParkOperator {
                                LabeledContent("Operator", value: op)
                                    .font(.caption)
                                    .copyable(op)
                            }
                            if let phone = carPark.contactDetails?.primaryTelephoneNumber?.telNationalNumber,
                               let url = makePhoneURL(phone) {
                                Link(destination: url) {
                                    LabeledContent("Phone", value: phone)
                                }
                                .font(.caption)
                                .copyable(phone)
                            }
                            if let website = carPark.contactDetails?.url,
                               let url = URL(string: website) {
                                Link(destination: url) {
                                    LabeledContent("Website") {
                                        Text(website)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                                .font(.caption)
                                .copyable(website)
                            }
                            if let hours = carPark.open?.dayAndTimeAvailability {
                                ForEach(Array(hours.enumerated()), id: \.offset) { _, entry in
                                    if let days = entry.dayTypes?.description,
                                       let time = entry.openingHours?.formatted, !time.isEmpty {
                                        LabeledContent(days, value: time)
                                            .font(.caption)
                                            .copyable(time)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Label("Car Park", systemImage: "car")
                                Spacer()
                                VStack(alignment: .trailing) {
                                    if let name = carPark.name {
                                        Text(name)
                                    }
                                    if let spaces = carPark.spaces {
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
                                if let name = carPark.name {
                                    Text(name)
                                }
                                if let spaces = carPark.spaces {
                                    Text("\(spaces) spaces")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                infoSectionHeader("Transport Links", icon: "arrow.triangle.branch")
            }

            // Fares Info
            Section {
                if let zone = info.fares?.travelcard?.travelcardZone {
                    LabeledContent("Travelcard Zone", value: zone)
                        .copyable(zone)
                }

                if info.fares?.prepurchaseCollection == true {
                    LabeledContent("Pre-purchase Collection", value: "Yes")
                }
                if info.fares?.smartcardIssued == true {
                    LabeledContent("Smartcard", value: "Yes")
                }
                if info.fares?.oysterPrePay == true {
                    LabeledContent("Oyster", value: "Yes")
                }

                if info.fares?.oysterTopup == true {
                    LabeledContent("Oyster Top-up", value: "Yes")
                }
                if info.fares?.oysterValidator == true {
                    LabeledContent("Oyster Validator", value: "Yes")
                }
                if info.fares?.smartcardTopup == true {
                    LabeledContent("Smartcard Top-up", value: "Yes")
                }
                if let comments = info.fares?.smartcardComments?.note {
                    let cleaned = stripHTML(comments)
                    if !cleaned.isEmpty {
                        Text(cleaned)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .copyable(cleaned)
                    }
                }

                if let penalty = info.fares?.penaltyFares?.note {
                    Text(richText(penalty))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .copyable(stripHTML(penalty))
                }
            } header: {
                infoSectionHeader("Fares", icon: "creditcard")
            }
            } // end Group 3
    }

    private func infoSectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.brand)
            .textCase(nil)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func facilityRow(_ name: String, icon: String, available: AvailableField?, hasDisclosureInSection: Bool = true) -> some View {
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
                        .padding(.trailing, hasDisclosureInSection ? 20 : 0)
                } label: {
                    Label(name, systemImage: icon)
                }
            }
        }
    }

    private func serviceHasContent(_ service: ServiceContactInfo) -> Bool {
        if service.contactDetails?.primaryTelephoneNumber?.telNationalNumber != nil { return true }
        if service.contactDetails?.url != nil { return true }
        if let note = service.open?.annotation?.note, !stripHTML(note).isEmpty { return true }
        if let avail = service.open?.dayAndTimeAvailability, !avail.isEmpty { return true }
        return false
    }

    @ViewBuilder
    private func serviceContactRows(service: ServiceContactInfo) -> some View {
        if serviceHasContent(service) {
            if let phone = service.contactDetails?.primaryTelephoneNumber?.telNationalNumber,
               let url = makePhoneURL(phone) {
                Link(destination: url) {
                    LabeledContent("Phone", value: phone)
                }
                .copyable(phone)
            }

            if let website = service.contactDetails?.url,
               let url = URL(string: website) {
                Link(destination: url) {
                    LabeledContent("Website") {
                        Text(website)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .copyable(website)
            }

            if let hours = service.open?.annotation?.note {
                let cleaned = stripHTML(hours)
                if !cleaned.isEmpty {
                    Text(cleaned)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .copyable(cleaned)
                }
            }

            if let availability = service.open?.dayAndTimeAvailability {
                ForEach(Array(availability.enumerated()), id: \.offset) { _, entry in
                    if let days = entry.dayTypes?.description,
                       let time = entry.openingHours?.formatted, !time.isEmpty {
                        LabeledContent(days, value: time)
                            .copyable(time)
                    }
                }
            }
        } else {
            Text("Not available")
                .foregroundStyle(.secondary)
        }
    }

    private func formattedAddress(_ info: StationInfo) -> String? {
        guard let address = info.address?.postalAddress?.a_5LineAddress else { return nil }
        var parts = address.line ?? []
        if let postcode = address.postCode {
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
        return String(richText(html).characters)
    }

    private func richText(_ html: String) -> AttributedString {
        var text = html
        // Decode HTML entities first
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        // Convert <strong> to markdown bold
        text = text.replacingOccurrences(of: "<strong[^>]*>", with: "**", options: .regularExpression)
        text = text.replacingOccurrences(of: "</strong>", with: "**", options: .caseInsensitive)
        // Block-level elements to newlines
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</h[1-6]>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</li>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<li[^>]*>", with: "• ", options: .regularExpression)
        // Strip remaining tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Fix trailing whitespace inside bold markers: "**word **" → "**word**"
        text = text.replacingOccurrences(of: #"\s+\*\*"#, with: "**", options: .regularExpression)
        // Fix literal * adjacent to bold marker: "***word" → "**word" (stray asterisk from source content)
        text = text.replacingOccurrences(of: #"\*\*\*([^\*])"#, with: "**$1", options: .regularExpression)
        // Collapse multiple blank lines
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Parse as markdown to get bold styling
        if let attributed = try? AttributedString(markdown: trimmed, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(trimmed)
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
            let result = try await StationViewModel.fetchStationInfo(crs: crs)
            print("Decoded \(crs): operator=\(result.stationOperator ?? "nil"), infoSystems=\(result.informationSystems != nil)")
            info = result
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load station information"
        }
        isLoading = false
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}

private struct CopyableModifier: ViewModifier {
    let value: String

    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                UIPasteboard.general.string = value
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }
}

extension View {
    func copyable(_ value: String) -> some View {
        modifier(CopyableModifier(value: value))
    }
}
