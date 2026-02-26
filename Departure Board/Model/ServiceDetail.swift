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
    let formation: Formation?

    /// Coaches extracted from the formation wrapper
    var coaches: [ServiceCoach] {
        formation?.coaches?.coach ?? []
    }
}

// MARK: - Formation (old nested format from service endpoint)

struct Formation: Codable {
    let coaches: CoachesContainer?
}

struct CoachesContainer: Codable {
    let coach: [ServiceCoach]?
}

struct ServiceCoach: Codable, Identifiable {
    let number: String
    let coachClass: String
    let loading: Int?
    let toilet: ServiceToilet?

    var id: String { number }

    var toiletDescription: String? {
        guard let toilet else { return nil }
        if toilet.type == "None" { return nil }
        var desc = toilet.type ?? "Unknown"
        if let status = toilet.status {
            desc += " (\(status))"
        }
        return desc
    }

    var loadingDescription: String? {
        guard let loading else { return nil }
        return "\(loading)%"
    }

    enum CodingKeys: String, CodingKey {
        case number, coachClass, loading, toilet
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decode(String.self, forKey: .number)
        coachClass = try container.decode(String.self, forKey: .coachClass)

        // loading can be String or Int or absent
        if let intVal = try? container.decode(Int.self, forKey: .loading) {
            loading = intVal
        } else if let strVal = try? container.decode(String.self, forKey: .loading), let parsed = Int(strVal) {
            loading = parsed
        } else {
            loading = nil
        }

        // toilet can be a String ("Standard") or an object {"_":"None","status":"Unknown"}
        // or the new format {"type":"Standard","status":null}
        toilet = try? container.decode(ServiceToilet.self, forKey: .toilet)
    }
}

/// Handles both old (`{ "_": "None", "status": "Unknown" }`) and
/// new (`{ "type": "Standard", "status": null }`) toilet formats,
/// as well as plain string values (`"Standard"`).
struct ServiceToilet: Codable, Hashable {
    let type: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case type, status
        case underscore = "_"
    }

    init(from decoder: Decoder) throws {
        // Try plain string first
        if let container = try? decoder.singleValueContainer(),
           let str = try? container.decode(String.self) {
            type = str
            status = nil
            return
        }

        // Object form
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let t = try? container.decode(String.self, forKey: .type) {
            type = t
        } else if let t = try? container.decode(String.self, forKey: .underscore) {
            type = t
        } else {
            type = nil
        }
        status = try? container.decode(String.self, forKey: .status)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(status, forKey: .status)
    }
}

// MARK: - Calling Points

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
