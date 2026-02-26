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
    let length: Int?
    let isCancelled: Bool
    let cancelReason: String?
    let delayReason: String?
    let overdueMessage: String?
    let previousCallingPoints: [[CallingPoint]]?
    let subsequentCallingPoints: [[CallingPoint]]?
}

struct CallingPoint: Codable, Identifiable {
    let locationName: String
    let crs: String
    let st: String
    let at: String?
    let et: String?
    let isCancelled: Bool?
    let cancelReason: String?
    let delayReason: String?
    let detachFront: Bool?
    let length: Int?

    var id: String { "\(crs)-\(st)" }

    var cancelled: Bool {
        isCancelled == true
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
        if value.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil {
            return value > st
        }
        return false
    }
}
