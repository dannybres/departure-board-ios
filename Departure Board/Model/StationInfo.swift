//
//  StationInfo.swift
//  Departure Board
//
//  Created by Daniel Breslan on 13/02/2026.
//

import Foundation

struct StationInfo: Codable {
    let name: String
    let crsCode: String
    let sixteenCharacterName: String?
    let stationOperator: String?
    let latitude: Double?
    let longitude: Double?
    let address: StationAddress?
    let staffing: StationStaffing?
    let informationSystems: InformationSystems?
    let fares: StationFares?
    let stationFacilities: StationFacilitiesInfo?
    let impairedAccess: StationImpairedAccess?
    let interchange: StationInterchange?
    let passengerServices: StationPassengerServices?
    let stationAlerts: StationAlerts?
}

// MARK: - Information Systems

struct InformationSystems: Codable {
    let departureScreens: Bool?
    let arrivalScreens: Bool?
    let announcements: Bool?

    var summary: String {
        var items: [String] = []
        if departureScreens == true { items.append("Departure Screens") }
        if arrivalScreens == true { items.append("Arrival Screens") }
        if announcements == true { items.append("Announcements") }
        return items.joined(separator: ", ")
    }
}

// MARK: - Passenger Services

struct StationPassengerServices: Codable {
    let customerService: AnnotationContainer?
    let lostProperty: ServiceContactInfo?
    let leftLuggage: ServiceContactInfo?
}

struct AnnotationContainer: Codable {
    let annotation: NoteContainer?
}

struct NoteContainer: Codable {
    let note: String?
}

struct ServiceContactInfo: Codable {
    let contactDetails: ContactDetails?
    let open: ServiceOpen?
    let available: Bool?
}

struct ContactDetails: Codable {
    let primaryTelephoneNumber: TelephoneNumber?
    let url: String?
    let annotation: NoteContainer?
}

struct TelephoneNumber: Codable {
    let telNationalNumber: String?
}

struct ServiceOpen: Codable {
    let annotation: NoteContainer?
    let dayAndTimeAvailability: [DayAndTime]?
}

struct TravelcardInfo: Codable {
    let travelcardZone: String?
}

// MARK: - Address

struct StationAddress: Codable {
    let postalAddress: PostalAddress?
}

struct PostalAddress: Codable {
    let a_5LineAddress: FiveLineAddress?
}

struct FiveLineAddress: Codable {
    let line: [String]?
    let postCode: String?
}

// MARK: - Staffing

struct StationStaffing: Codable {
    let staffingLevel: String?
    let closedCircuitTelevision: CCTVInfo?
}

struct CCTVInfo: Codable {
    let overall: Bool?
}

// MARK: - Fares

struct StationFares: Codable {
    let ticketOffice: TicketOffice?
    let ticketMachine: AvailableField?
    let prepurchaseCollection: Bool?
    let smartcardIssued: Bool?
    let oysterPrePay: Bool?
    let penaltyFares: NoteField?
    let travelcard: TravelcardInfo?
    let oysterTopup: Bool?
    let oysterValidator: Bool?
    let smartcardTopup: Bool?
    let smartcardComments: NoteField?
}

struct TicketOffice: Codable {
    let annotation: NoteContainer?
    let open: TicketOfficeOpen?
}

struct TicketOfficeOpen: Codable {
    let annotation: NoteContainer?
    let dayAndTimeAvailability: [DayAndTime]?
}

struct DayAndTime: Codable {
    let dayTypes: DayTypes?
    let openingHours: OpeningHours?

    // dayTypes can be either an object or an empty string "" — handle both gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        openingHours = try container.decodeIfPresent(OpeningHours.self, forKey: .openingHours)
        if let dt = try? container.decodeIfPresent(DayTypes.self, forKey: .dayTypes) {
            dayTypes = dt
        } else {
            dayTypes = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case dayTypes, openingHours
    }
}

struct DayTypes: Codable {
    let mondayToFriday: String?
    let mondayToSaturday: String?
    let mondayToSunday: String?
    let monday: String?
    let tuesday: String?
    let wednesday: String?
    let thursday: String?
    let friday: String?
    let saturday: String?
    let sunday: String?
    let weekend: String?

    var description: String {
        var days: [String] = []
        if mondayToFriday != nil { days.append("Mon–Fri") }
        if mondayToSaturday != nil { days.append("Mon–Sat") }
        if mondayToSunday != nil { days.append("Mon–Sun") }
        if monday != nil { days.append("Mon") }
        if tuesday != nil { days.append("Tue") }
        if wednesday != nil { days.append("Wed") }
        if thursday != nil { days.append("Thu") }
        if friday != nil { days.append("Fri") }
        if saturday != nil { days.append("Sat") }
        if sunday != nil { days.append("Sun") }
        if weekend != nil { days.append("Weekends") }
        return days.joined(separator: ", ")
    }
}

struct OpeningHours: Codable {
    let openPeriod: [OpenPeriod]?
    let twentyFourHours: String?
    let unavailable: String?

    var formatted: String {
        if twentyFourHours != nil { return "24 hours" }
        if unavailable != nil { return "Unavailable" }
        guard let periods = openPeriod, !periods.isEmpty else { return "" }
        return periods.map { $0.formatted }.joined(separator: ", ")
    }
}

struct OpenPeriod: Codable {
    let startTime: String?
    let endTime: String?

    var formatted: String {
        guard let start = startTime, let end = endTime else { return "" }
        return "\(formatTime(start)) – \(formatTime(end))"
    }

    private func formatTime(_ time: String) -> String {
        let parts = time.split(separator: ":")
        if parts.count >= 2 {
            return "\(parts[0]):\(parts[1])"
        }
        return time
    }
}

// MARK: - Facilities

struct StationFacilitiesInfo: Codable {
    let toilets: AvailableField?
    let wiFi: AvailableField?
    let waitingRoom: AvailableField?
    let shops: AvailableField?
    let atmMachine: AvailableField?
    let babyChange: AvailableField?
    let stationBuffet: AvailableField?
    let showers: AvailableField?
    let postBox: AvailableField?
    let trolleys: AvailableField?
    let firstClassLounge: FirstClassLounge?
    let seatedArea: AvailableField?
}

struct AvailableField: Codable {
    let available: Bool?
    let note: String?
    let annotation: NoteContainer?

    var isAvailable: Bool {
        available == true
    }

    var noteText: String? {
        note ?? annotation?.note
    }
}

struct NoteField: Codable {
    let note: String?
}

struct FirstClassLounge: Codable {
    let annotation: NoteContainer?
    let open: TicketOfficeOpen?
}

// MARK: - Impaired Access

struct StationImpairedAccess: Codable {
    let helpline: AccessHelpline?
    let customerHelpPoints: AvailableField?
    let staffHelpAvailable: StaffHelpAvailable?
    let stepFreeAccess: StepFreeAccess?
    let ticketGate: Bool?
    let ticketGateComments: NoteField?
    let inductionLoop: Bool?
    let accessibleTicketMachines: AvailableField?
    let accessibleBookingOfficeCounter: AvailableField?
    let wheelchairsAvailable: AvailableField?
    let rampForTrainAccess: AvailableField?
    let accessibleTaxis: AvailableField?
    let accessiblePublicTelephones: AvailableField?
    let nationalKeyToilets: AvailableField?
    let impairedMobilitySetDown: AvailableField?
}

struct AccessHelpline: Codable {
    let annotation: NoteContainer?
    let contactDetails: ContactDetails?
    let open: ServiceOpen?
}

struct StaffHelpAvailable: Codable {
    let annotation: NoteContainer?
    let open: ServiceOpen?
}

struct StepFreeAccess: Codable {
    let annotation: NoteContainer?
    let coverage: String?
}

// MARK: - Interchange

struct StationInterchange: Codable {
    let cycleStorageAvailability: Bool?
    let cycleStorageSpaces: Int?
    let cycleStorageSheltered: Bool?
    let cycleStorageCctv: Bool?
    let cycleStorageLocation: String?
    let cycleStorageNote: NoteField?
    let cycleStorageType: [String]?
    let taxiRank: AvailableField?
    let busServices: AvailableField?
    let metroServices: AvailableField?
    let carPark: CarParkInfo?
    let railReplacementServices: RailReplacementServices?
    let airport: AvailableField?
    let carHire: AvailableField?
    let cycleHire: AvailableField?
}

struct RailReplacementServices: Codable {
    let annotation: NoteContainer?
    let railReplacementMap: String?
}

struct CarParkInfo: Codable {
    let name: String?
    let spaces: Int?
    let carParkOperator: String?
    let contactDetails: ContactDetails?
    let open: ServiceOpen?
    let charges: CarParkCharges?

    enum CodingKeys: String, CodingKey {
        case name, spaces, contactDetails, open, charges
        case carParkOperator = "operator"
    }
}

struct CarParkCharges: Codable {
    let free: Bool?
    let daily: String?
    let hourly: String?
    let perHour: String?
    let offPeak: String?
    let weekly: String?
    let monthly: String?
    let threeMonthly: String?
    let annual: String?
    let note: String?

    var effectiveHourly: String? { hourly ?? perHour }
}

// MARK: - Alerts

struct StationAlerts: Codable {
    let alertText: String?
}

// MARK: - Nearest Stations

struct NearestStationsWithMoreFacilities: Codable {
    let crsCode: [String]?
}
