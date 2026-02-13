//
//  Board.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import Foundation

struct DepartureBoard: Codable {
    let generatedAt: String
    let locationName: String
    let crs: String
    let platformAvailable: String
    
    let trainServices: TrainServices?
}

struct TrainServices: Codable {
    let service: [Service]
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
    let serviceID: String
    
    let origin: LocationContainer
    let destination: LocationContainer
    
    var id: String { serviceID }

    var scheduled: String { sta ?? std ?? "missing" }
    var estimated: String { eta ?? etd ?? "missing" }
}

struct LocationContainer: Codable, Hashable {
    let location: [Location]
}

struct Location: Codable, Hashable {
    let locationName: String
    let crs: String
    let via: String?
}
