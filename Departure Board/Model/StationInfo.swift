//
//  StationInfo.swift
//  Departure Board
//
//  Created by Daniel Breslan on 13/02/2026.
//

import Foundation

struct StationInfo: Codable {
    let Name: String
    let CrsCode: String
    let SixteenCharacterName: String?
    let StationOperator: String?
    let Latitude: String?
    let Longitude: String?
    let Address: StationAddress?
    let Staffing: StationStaffing?
    let InformationSystems: InformationSystems?
    let Fares: StationFares?
    let StationFacilities: StationFacilitiesInfo?
    let ImpairedAccess: StationImpairedAccess?
    let Interchange: StationInterchange?
    let PassengerServices: StationPassengerServices?
    let StationAlerts: StationAlerts?
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
    let CustomerService: AnnotationContainer?
    let LostProperty: ServiceContactInfo?
    let LeftLuggage: ServiceContactInfo?
}

struct AnnotationContainer: Codable {
    let Annotation: NoteContainer?
}

struct NoteContainer: Codable {
    let Note: String?
}

struct ServiceContactInfo: Codable {
    let ContactDetails: ContactDetails?
    let Open: ServiceOpen?
    let Available: String?
}

struct ContactDetails: Codable {
    let PrimaryTelephoneNumber: TelephoneNumber?
    let Url: String?
    let Annotation: NoteContainer?
}

struct TelephoneNumber: Codable {
    let TelNationalNumber: String?
}

struct ServiceOpen: Codable {
    let Annotation: NoteContainer?
    let DayAndTimeAvailability: DayAndTimeValue?
}

struct TravelcardInfo: Codable {
    let TravelcardZone: String?
}

// MARK: - Address

struct StationAddress: Codable {
    let PostalAddress: PostalAddress?
}

struct PostalAddress: Codable {
    let A_5LineAddress: FiveLineAddress?
}

struct FiveLineAddress: Codable {
    let Line: LineValue?
    let PostCode: String?

    enum CodingKeys: String, CodingKey {
        case Line, PostCode
    }
}

// Line can be a single string or an array of strings
enum LineValue: Codable {
    case single(String)
    case multiple([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([String].self) {
            self = .multiple(array)
        } else if let string = try? container.decode(String.self) {
            self = .single(string)
        } else {
            self = .multiple([])
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let s): try container.encode(s)
        case .multiple(let a): try container.encode(a)
        }
    }

    var lines: [String] {
        switch self {
        case .single(let s): return [s]
        case .multiple(let a): return a
        }
    }
}

// MARK: - Staffing

struct StationStaffing: Codable {
    let StaffingLevel: String?
    let ClosedCircuitTelevision: CCTVInfo?
}

struct CCTVInfo: Codable {
    let Overall: String?
}

// MARK: - Fares

struct StationFares: Codable {
    let TicketOffice: TicketOffice?
    let TicketMachine: AvailableField?
    let PrepurchaseCollection: String?
    let SmartcardIssued: String?
    let OysterPrePay: String?
    let PenaltyFares: NoteField?
    let Travelcard: TravelcardInfo?
    let OysterTopup: String?
    let OysterValidator: String?
    let SmartcardTopup: String?
    let SmartcardComments: NoteField?
}

struct TicketOffice: Codable {
    let Annotation: NoteContainer?
    let Open: TicketOfficeOpen?
}

struct TicketOfficeOpen: Codable {
    let Annotation: NoteContainer?
    let DayAndTimeAvailability: DayAndTimeValue?
}

// DayAndTimeAvailability can be a single object or array
enum DayAndTimeValue: Codable {
    case single(DayAndTime)
    case multiple([DayAndTime])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([DayAndTime].self) {
            self = .multiple(array)
        } else if let single = try? container.decode(DayAndTime.self) {
            self = .single(single)
        } else {
            self = .multiple([])
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let s): try container.encode(s)
        case .multiple(let a): try container.encode(a)
        }
    }

    var items: [DayAndTime] {
        switch self {
        case .single(let s): return [s]
        case .multiple(let a): return a
        }
    }
}

struct DayAndTime: Codable {
    let DayTypes: DayTypes?
    let OpeningHours: OpeningHours?
}

struct DayTypes: Codable {
    let MondayToFriday: String?
    let MondayToSaturday: String?
    let MondayToSunday: String?
    let Monday: String?
    let Tuesday: String?
    let Wednesday: String?
    let Thursday: String?
    let Friday: String?
    let Saturday: String?
    let Sunday: String?

    var description: String {
        var days: [String] = []
        if MondayToFriday != nil { days.append("Mon–Fri") }
        if MondayToSaturday != nil { days.append("Mon–Sat") }
        if MondayToSunday != nil { days.append("Mon–Sun") }
        if Monday != nil { days.append("Mon") }
        if Tuesday != nil { days.append("Tue") }
        if Wednesday != nil { days.append("Wed") }
        if Thursday != nil { days.append("Thu") }
        if Friday != nil { days.append("Fri") }
        if Saturday != nil { days.append("Sat") }
        if Sunday != nil { days.append("Sun") }
        return days.joined(separator: ", ")
    }
}

struct OpeningHours: Codable {
    let OpenPeriod: OpenPeriod?
    let TwentyFourHours: String?

    var formatted: String {
        if TwentyFourHours != nil { return "24 hours" }
        return OpenPeriod?.formatted ?? ""
    }
}

struct OpenPeriod: Codable {
    let StartTime: String?
    let EndTime: String?

    var formatted: String {
        guard let start = StartTime, let end = EndTime else { return "" }
        return "\(formatTime(start)) – \(formatTime(end))"
    }

    private func formatTime(_ time: String) -> String {
        // "06:00:00.000" -> "06:00"
        let parts = time.split(separator: ":")
        if parts.count >= 2 {
            return "\(parts[0]):\(parts[1])"
        }
        return time
    }
}

// MARK: - Facilities

struct StationFacilitiesInfo: Codable {
    let Toilets: AvailableField?
    let WiFi: AvailableField?
    let WaitingRoom: AvailableField?
    let Shops: AvailableField?
    let AtmMachine: AvailableField?
    let BabyChange: AvailableField?
    let StationBuffet: AvailableField?
    let Showers: AvailableField?
    let PostBox: AvailableField?
    let Trolleys: AvailableField?
    let FirstClassLounge: FirstClassLounge?
    let SeatedArea: AvailableField?
}

struct AvailableField: Codable {
    let Available: String?
    let Note: String?
    let Annotation: NoteContainer?

    var isAvailable: Bool {
        Available?.lowercased() == "true"
    }

    var noteText: String? {
        Note ?? Annotation?.Note
    }
}

struct NoteField: Codable {
    let Note: String?
}

struct FirstClassLounge: Codable {
    let Annotation: NoteContainer?
    let Open: TicketOfficeOpen?
}

// MARK: - Impaired Access

struct StationImpairedAccess: Codable {
    let Helpline: AccessHelpline?
    let CustomerHelpPoints: AvailableField?
    let StaffHelpAvailable: StaffHelpAvailable?
    let StepFreeAccess: StepFreeAccess?
    let TicketGate: String?
    let TicketGateComments: NoteField?
    let InductionLoop: String?
    let AccessibleTicketMachines: AvailableField?
    let AccessibleBookingOfficeCounter: AvailableField?
    let WheelchairsAvailable: AvailableField?
    let RampForTrainAccess: AvailableField?
    let AccessibleTaxis: AnnotationContainer?
    let AccessiblePublicTelephones: AnnotationContainer?
    let NationalKeyToilets: AvailableField?
    let ImpairedMobilitySetDown: AvailableField?
}

struct AccessHelpline: Codable {
    let Annotation: NoteContainer?
    let ContactDetails: ContactDetails?
    let Open: ServiceOpen?
}

struct StaffHelpAvailable: Codable {
    let Annotation: NoteContainer?
    let Open: ServiceOpen?
}

struct StepFreeAccess: Codable {
    let Annotation: NoteContainer?
    let Coverage: String?
}

// MARK: - Interchange

struct StationInterchange: Codable {
    let CycleStorageAvailability: String?
    let CycleStorageSpaces: String?
    let CycleStorageSheltered: String?
    let CycleStorageCctv: String?
    let CycleStorageLocation: String?
    let CycleStorageNote: NoteField?
    let CycleStorageType: FlexibleStringValue?
    let TaxiRank: AvailableField?
    let BusServices: AvailableField?
    let MetroServices: AvailableField?
    let CarPark: FlexibleCarParkValue?
    let RailReplacementServices: AnnotationContainer?
    let Airport: AvailableField?
    let CarHire: AvailableField?
    let CycleHire: AvailableField?
}

// CycleStorageType can be a single string or array of strings
enum FlexibleStringValue: Codable {
    case single(String)
    case multiple([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([String].self) {
            self = .multiple(array)
        } else if let string = try? container.decode(String.self) {
            self = .single(string)
        } else {
            self = .multiple([])
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let s): try container.encode(s)
        case .multiple(let a): try container.encode(a)
        }
    }

    var text: String {
        switch self {
        case .single(let s): return s
        case .multiple(let a): return a.joined(separator: ", ")
        }
    }
}

// CarPark can be a single object or array of objects
enum FlexibleCarParkValue: Codable {
    case single(CarParkInfo)
    case multiple([CarParkInfo])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([CarParkInfo].self) {
            self = .multiple(array)
        } else if let single = try? container.decode(CarParkInfo.self) {
            self = .single(single)
        } else {
            self = .multiple([])
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let s): try container.encode(s)
        case .multiple(let a): try container.encode(a)
        }
    }

    var items: [CarParkInfo] {
        switch self {
        case .single(let s): return [s]
        case .multiple(let a): return a
        }
    }
}

struct CarParkInfo: Codable {
    let Name: String?
    let Spaces: String?
    let Operator: String?
    let ContactDetails: ContactDetails?
    let Open: ServiceOpen?
}

// MARK: - Alerts

struct StationAlerts: Codable {
    let AlertText: AlertTextValue?
}

enum AlertTextValue: Codable {
    case single(String)
    case multiple([String])
    case empty

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([String].self) {
            self = array.isEmpty ? .empty : .multiple(array)
        } else if let string = try? container.decode(String.self) {
            self = string.isEmpty ? .empty : .single(string)
        } else {
            self = .empty
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let s): try container.encode(s)
        case .multiple(let a): try container.encode(a)
        case .empty: try container.encode("")
        }
    }

    var texts: [String] {
        switch self {
        case .single(let s): return [s]
        case .multiple(let a): return a
        case .empty: return []
        }
    }
}
