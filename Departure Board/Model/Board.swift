//
//  Board.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import Foundation

struct BoardRequest: Encodable {
    let crs: String
    let type: String
    let filterCrs: String?
    let filterType: String?

    enum CodingKeys: String, CodingKey {
        case crs, type, filterCrs, filterType
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(crs, forKey: .crs)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(filterCrs, forKey: .filterCrs)
        try container.encodeIfPresent(filterType, forKey: .filterType)
    }
}

struct BoardSummary: Codable {
    let crs: String
    let type: String
    let filterCrs: String?
    let filterType: String?
    let generatedAt: String?
    let locationName: String?
    let nrccMessages: [String]?
    let service: Service?
    let error: String?
}

struct DepartureBoard: Codable {
    let generatedAt: String
    let locationName: String
    let crs: String
    let filterLocationName: String?
    let filtercrs: String?
    let platformAvailable: Bool

    let nrccMessages: [String]?
    let trainServices: [Service]?
    let busServices: [Service]?
}

struct Service: Codable, Identifiable, Hashable {

    let std: String?
    let etd: String?
    let sta: String?
    let eta: String?
    let platform: String?

    let `operator`: String
    let operatorCode: String
    let serviceType: String
    let serviceId: String
    let rsid: String?
    let length: Int?
    let isCancelled: Bool
    let cancelReason: String?
    let delayReason: String?
    let futureCancellation: Bool?

    let origin: [Location]
    let destination: [Location]
    let currentOrigins: [Location]?
    let currentDestinations: [Location]?

    let coaches: [Coach]?

    var id: String { serviceId }

    var scheduled: String { sta ?? std ?? "missing" }
    var estimated: String { eta ?? etd ?? "missing" }
}

struct Location: Codable, Hashable {
    let locationName: String
    let crs: String
    let via: String?
}

struct Coach: Codable, Hashable {
    let number: String
    let coachClass: String
    let loading: Int?
    let toilet: Toilet?
}

struct Toilet: Codable, Hashable {
    let type: String?
    let status: String?
}
