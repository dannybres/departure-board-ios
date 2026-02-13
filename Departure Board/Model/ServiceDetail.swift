//
//  ServiceDetail.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import Foundation

struct ServiceDetail: Codable {
    let generatedAt: String
    let locationName: String
    let crs: String
    let `operator`: String
    let operatorCode: String
    let serviceType: String
    let std: String?
    let etd: String?
    let sta: String?
    let eta: String?
    let ata: String?
    let atd: String?
    let platform: String?
    let length: String?
    let delayReason: String?
    let overdueMessage: String?
    let previousCallingPoints: CallingPointListContainer?
    let subsequentCallingPoints: CallingPointListContainer?
    
//    var scheduled: String { sta ?? std ?? "missing" }
//    var estimated: String { eta ?? etd ?? "missing" }
//    var actual: String { ata ?? atd ?? "missing" }
}

struct CallingPointListContainer: Codable {
    let callingPointList: [CallingPointList]
}

struct CallingPointList: Codable {
    let callingPoint: [CallingPoint]
}

struct CallingPoint: Codable, Identifiable {
    let locationName: String
    let crs: String
    let st: String
    let at: String?
    let et: String?
    let isCancelled: String?
    let cancelReason: String?
    let delayReason: String?
    let length: String?

    var id: String { "\(crs)-\(st)" }

    var cancelled: Bool {
        isCancelled?.lowercased() == "true"
    }

    var status: String {
        if cancelled { return "Cancelled" }
        if let at { return at }
        if let et { return et }
        return ""
    }

    var isLate: Bool {
        let value = status
        if value.lowercased() == "on time" || value.isEmpty || value == "No report" { return false }
        if value.lowercased().contains("cancel") { return true }
        if value.lowercased().contains("delayed") { return true }
        // If it's a time, compare to scheduled
        if value.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil {
            return value > st
        }
        return false
    }
}
