//
//  Station.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import Foundation

struct Station: Codable, Identifiable, Hashable {
    
    let crsCode: String
    let name: String
    let `operator`: String
    let postCode: String
    let longitude: Double
    let latitude: Double
    let departureScreens: Bool
    let arrivalScreens: Bool
    let announcements: Bool
    
    var id: String { crsCode }
}

