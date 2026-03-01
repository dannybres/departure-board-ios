//
//  StationInfoView.swift
//  Departure Board
//
//  Created by Daniel Breslan on 13/02/2026.
//

import SwiftUI
import MapKit

private struct InfoLoadState {
    var info: StationInfo? = nil
    var isLoading: Bool = true
    var errorMessage: String? = nil
}

struct StationInfoView: View {

    let crs: String
    let onDismiss: () -> Void
    var onNavigate: ((BoardType) -> Void)? = nil

    @State private var loadState = InfoLoadState()
    @State private var pendingCall: (number: String, url: URL)?
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

                    if let info = loadState.info {
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
                if let info = loadState.info {
                    stationInfoSections(info)
                } else if let errorMessage = loadState.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else if loadState.isLoading {
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
            .navigationTitle(loadState.info?.name ?? cachedStation?.name ?? crs)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                }
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "tel" {
                let raw = url.absoluteString.replacingOccurrences(of: "tel:", with: "")
                let display = raw.replacingOccurrences(of: "%2B", with: "+")
                pendingCall = (number: display, url: url)
                return .handled
            }
            return .systemAction
        })
        .confirmationDialog(
            pendingCall.map { "Call \($0.number)" } ?? "",
            isPresented: Binding(get: { pendingCall != nil }, set: { if !$0 { pendingCall = nil } }),
            titleVisibility: .visible
        ) {
            if let call = pendingCall {
                Button("Call \(call.number)") {
                    UIApplication.shared.open(call.url)
                }
                Button("Copy Number") {
                    UIPasteboard.general.string = call.number
                }
                Button("Cancel", role: .cancel) { }
            }
        }
        .task {
            await loadInfo()
        }
    }

    private var mapLatitude: Double? {
        if let info = loadState.info, let lat = info.latitude { return lat }
        return cachedStation?.latitude
    }

    private var mapLongitude: Double? {
        if let info = loadState.info, let lon = info.longitude { return lon }
        return cachedStation?.longitude
    }

    private var mapName: String {
        loadState.info?.name ?? cachedStation?.name ?? crs
    }

    @ViewBuilder
    private func stationInfoSections(_ info: StationInfo) -> some View {
            // Group 1: Alerts, InformationSystems, CustomerService
            Group {
            // Alerts
            if let alertText = info.stationAlerts?.alertText, !alertText.isEmpty {
                Section {
                    richText(alertText)
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
                        richNoteCell(note)
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
                    if let locationNote = info.fares?.ticketOffice?.annotation?.note, !stripHTML(locationNote).isEmpty {
                        richNoteCell(locationNote)
                    }

                    if let advanceNote = info.fares?.ticketOffice?.open?.annotation?.note, !stripHTML(advanceNote).isEmpty {
                        richNoteCell(advanceNote)
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
                                richText(note)
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
                            richText(note)
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
                            richText(comments)
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
                                richText(note)
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
                                richText(note)
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
                                richText(contactNote)
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

                if let rrs = info.interchange?.railReplacementServices, let note = rrs.annotation?.note, !stripHTML(note).isEmpty {
                    DisclosureGroup {
                        richNoteCell(note)
                    } label: {
                        Label("Rail Replacement", systemImage: "bus.doubledecker")
                    }
                }

                if info.interchange?.cycleStorageAvailability == true {
                    let hasExtra = info.interchange?.cycleStorageNote?.note != nil || info.interchange?.cycleStorageLocation != nil
                    if hasExtra {
                        DisclosureGroup {
                            if let location = info.interchange?.cycleStorageLocation {
                                richText(location)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let note = info.interchange?.cycleStorageNote?.note {
                                richText(note)
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

                if let carParks = info.interchange?.carPark {
                    ForEach(Array(carParks.enumerated()), id: \.offset) { _, carPark in
                        let charges = carPark.charges
                        let hasCharges = charges?.effectiveHourly != nil || charges?.daily != nil || charges?.offPeak != nil || charges?.weekly != nil || charges?.monthly != nil || charges?.annual != nil || charges?.free == true
                        let hasExtra = hasCharges || carPark.contactDetails?.url != nil || carPark.contactDetails?.primaryTelephoneNumber?.telNationalNumber != nil || carPark.open?.dayAndTimeAvailability != nil
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
                                if let c = charges {
                                    if c.free == true {
                                        LabeledContent("Parking", value: "Free")
                                            .font(.caption)
                                    }
                                    if let v = c.effectiveHourly {
                                        LabeledContent("Per hour", value: v)
                                            .font(.caption)
                                            .copyable(v)
                                    }
                                    if let v = c.offPeak {
                                        LabeledContent("Off-peak", value: v)
                                            .font(.caption)
                                            .copyable(v)
                                    }
                                    if let v = c.daily {
                                        LabeledContent("Daily", value: v)
                                            .font(.caption)
                                            .copyable(v)
                                    }
                                    if let v = c.weekly {
                                        LabeledContent("Weekly", value: v)
                                            .font(.caption)
                                            .copyable(v)
                                    }
                                    if let v = c.monthly {
                                        LabeledContent("Monthly", value: v)
                                            .font(.caption)
                                            .copyable(v)
                                    }
                                    if let v = c.threeMonthly {
                                        LabeledContent("3 months", value: v)
                                            .font(.caption)
                                            .copyable(v)
                                    }
                                    if let v = c.annual {
                                        LabeledContent("Annual", value: v)
                                            .font(.caption)
                                            .copyable(v)
                                    }
                                    if let note = c.note, !note.isEmpty {
                                        richNoteCell(note)
                                    }
                                }
                            } label: {
                                HStack {
                                    Label("Car Park", systemImage: "car")
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        if let name = carPark.name {
                                            Text(name.trimmingCharacters(in: .whitespaces))
                                        }
                                        if let spaces = carPark.spaces {
                                            Text("\(spaces) spaces")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let daily = charges?.daily {
                                            Text(daily + " /day")
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
                                        Text(name.trimmingCharacters(in: .whitespaces))
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
                if let comments = info.fares?.smartcardComments?.note, !stripHTML(comments).isEmpty {
                    richNoteCell(comments)
                }

                if let penalty = info.fares?.penaltyFares?.note, !stripHTML(penalty).isEmpty {
                    richNoteCell(penalty)
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
            if let rawNote = field.noteText, !rawNote.isEmpty {
                DisclosureGroup {
                    richNoteCell(rawNote)
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

            if let hours = service.open?.annotation?.note, !stripHTML(hours).isEmpty {
                richNoteCell(hours)
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

    private func processToMarkdown(_ input: String) -> String {
        var text = input
        // Always decode basic HTML entities
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        // Convert HTML tags if present
        if text.range(of: "<[a-zA-Z]", options: .regularExpression) != nil {
            text = text.replacingOccurrences(of: "<strong[^>]*>", with: "**", options: .regularExpression)
            text = text.replacingOccurrences(of: "</strong>", with: "**", options: .caseInsensitive)
            text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            text = text.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
            text = text.replacingOccurrences(of: "</h[1-6]>", with: "\n", options: .regularExpression)
            text = text.replacingOccurrences(of: "</li>", with: "\n", options: .caseInsensitive)
            text = text.replacingOccurrences(of: "<li[^>]*>", with: "• ", options: .regularExpression)
            text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            text = text.replacingOccurrences(of: #"\s+\*\*"#, with: "**", options: .regularExpression)
            text = text.replacingOccurrences(of: #"\*\*\*([^\*])"#, with: "**$1", options: .regularExpression)
        }
        // Strip ** immediately wrapping numeric content e.g. **0800 123 4567**
        text = text.replacingOccurrences(of: #"\*\*([\d][\d\s\-\+]*)\*\*"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripHTML(_ input: String) -> String {
        let md = processToMarkdown(input)
        return md.replacingOccurrences(of: "**", with: "")
    }

    private func richText(_ input: String) -> Text {
        let processed = linkifyPhoneNumbers(processToMarkdown(input))
        if var attributed = try? AttributedString(markdown: processed,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            for run in attributed.runs where run.link != nil {
                attributed[run.range].foregroundColor = UIColor.link
            }
            return Text(attributed)
        }
        return Text(processed)
    }

    private func linkifyPhoneNumbers(_ text: String) -> String {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
        else { return text }

        // Ranges already inside markdown links — skip these
        var existingLinkRanges: [Range<String.Index>] = []
        let linkPattern = #"\[[^\]]*\]\([^\)]*\)"#
        var sr = text.startIndex..<text.endIndex
        while let r = text.range(of: linkPattern, options: .regularExpression, range: sr) {
            existingLinkRanges.append(r); sr = r.upperBound..<text.endIndex
        }

        struct PhoneMatch {
            let range: Range<String.Index>
            let display: String
            let tel: String
        }
        var phoneMatches: [PhoneMatch] = []
        var coveredRanges: [Range<String.Index>] = []

        // Pre-pass: 18001 textphone relay numbers (e.g. "18001 0330 060 0500")
        sr = text.startIndex..<text.endIndex
        while let r = text.range(of: #"\b18001[\s\-]?\d[\d\s\-]{9,15}"#,
                                  options: .regularExpression, range: sr) {
            if !existingLinkRanges.contains(where: { $0.overlaps(r) }) {
                let display = String(text[r]).trimmingCharacters(in: .whitespaces)
                let digits = display.replacingOccurrences(of: "[^\\d]", with: "", options: .regularExpression)
                phoneMatches.append(PhoneMatch(range: r, display: display, tel: digits))
                coveredRanges.append(r)
            }
            sr = r.upperBound..<text.endIndex
        }

        // Standard numbers via NSDataDetector (skip anything already covered by 18001 pre-pass)
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let r = Range(match.range, in: text) else { continue }
            if existingLinkRanges.contains(where: { $0.overlaps(r) }) { continue }
            if coveredRanges.contains(where: { $0.overlaps(r) }) { continue }
            let display = String(text[r])
            let digits = display.replacingOccurrences(of: "[^\\d+]", with: "", options: .regularExpression)
            let tel = digits.hasPrefix("+") ? digits : digits.hasPrefix("0") ? "+44" + digits.dropFirst() : digits
            guard !tel.isEmpty else { continue }
            phoneMatches.append(PhoneMatch(range: r, display: display, tel: tel))
        }

        // Replace in reverse order so earlier indices stay valid
        var result = text
        for m in phoneMatches.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            let lo = result.index(result.startIndex, offsetBy: text.distance(from: text.startIndex, to: m.range.lowerBound))
            let hi = result.index(result.startIndex, offsetBy: text.distance(from: text.startIndex, to: m.range.upperBound))
            result.replaceSubrange(lo..<hi, with: "[\(m.display)](tel:\(m.tel))")
        }
        return result
    }

    @ViewBuilder
    private func richNoteCell(_ note: String) -> some View {
        let urls = extractAllURLs(from: note)
        let singleURL = urls.count == 1 ? urls.first : nil
        VStack(alignment: .leading, spacing: 4) {
            richText(note)
                .font(.caption)
                .foregroundStyle(.secondary)
            if singleURL != nil {
                Label("Open link", systemImage: "arrow.up.right.square")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.brand)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = singleURL { UIApplication.shared.open(url) }
        }
    }

    private func extractAllURLs(from text: String) -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()
        // Markdown links [label](url)
        let mdPattern = #"\[([^\]]+)\]\((https?://[^\)]+)\)"#
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: mdPattern, options: .regularExpression, range: searchRange) {
            if let urlRange = text[range].range(of: #"https?://[^\)]+"#, options: .regularExpression) {
                let urlStr = String(text[range][urlRange])
                if !seen.contains(urlStr), let url = URL(string: urlStr) {
                    urls.append(url)
                    seen.insert(urlStr)
                }
            }
            searchRange = range.upperBound..<text.endIndex
        }
        // Bare URLs not already captured
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let url = match.url, !seen.contains(url.absoluteString) {
                    urls.append(url)
                    seen.insert(url.absoluteString)
                }
            }
        }
        return urls
    }

    private func extractFirstURL(from text: String) -> URL? {
        extractAllURLs(from: text).first
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
            loadState.info = result
            loadState.errorMessage = nil
        } catch {
            loadState.errorMessage = "Failed to load station information"
        }
        loadState.isLoading = false
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
