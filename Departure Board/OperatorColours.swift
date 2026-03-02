//
//  OperatorColours.swift
//  Departure Board
//

import SwiftUI

// MARK: - Style Enums

enum RowTheme: String, CaseIterable {
    case none          = "none"
    case trackline     = "trackline"
    case signalRail    = "signalRail"
    case timeTile      = "timeTile"
    case timePanel     = "timePanel"
    case platformPulse = "platformPulse"
    case boardWash     = "boardWash"

    var displayName: String {
        switch self {
        case .none:          return "None"
        case .trackline:     return "Trackline"
        case .signalRail:    return "Signal Rail"
        case .timeTile:      return "Time Tile"
        case .timePanel:     return "Time Panel"
        case .platformPulse: return "Platform Pulse"
        case .boardWash:     return "Board Wash"
        }
    }
}

enum ColourVibrancy: String, CaseIterable {
    case vibrant = "vibrant"
    case tinted  = "tinted"

    var displayName: String {
        switch self {
        case .vibrant: return "Vibrant"
        case .tinted:  return "Tinted"
        }
    }

    var opacity: Double {
        self == .vibrant ? 1.0 : 0.22
    }
}

// MARK: - Colour Lookup

struct OperatorColours {

    struct Entry {
        let primary: Color
        let secondary: Color
        /// True when the primary colour is bright enough that dark text is needed for legibility.
        let primaryIsLight: Bool
    }

    // Raw hex pairs keyed by two-letter TOC code. ZZ = default/unknown.
    private static let table: [String: (String, String)] = [
        "AW": ("#00A3A6", "#231F20"),
        "CC": ("#B81C8D", "#FFFFFF"),
        "CH": ("#000080", "#FFFFFF"),
        "EM": ("#582C83", "#FFFFFF"),
        "ES": ("#0C1C8C", "#FFFFFF"),
        "GM": ("#003057", "#F0B400"),
        "GN": ("#1D2D5C", "#FFFFFF"),
        "GR": ("#CF0A2C", "#FFFFFF"),
        "GW": ("#0B2D27", "#FFFFFF"),
        "GX": ("#CF0A2C", "#FFFFFF"),
        "HS": ("#1D2D5C", "#FFFFFF"),
        "HV": ("#003057", "#F0B400"),
        "HX": ("#4B006E", "#C8C9CB"),
        "IL": ("#1E90FF", "#FFFFFF"),
        "LE": ("#CC0000", "#FFFFFF"),
        "LN": ("#004CA4", "#FFFFFF"),
        "LO": ("#EE7C0E", "#FFFFFF"),
        "LT": ("#E32017", "#FFFFFF"),
        "ME": ("#FFF200", "#000000"),
        "NR": ("#003057", "#F0B400"),
        "NT": ("#23335F", "#FFD777"),
        "SE": ("#1D2D5C", "#FFFFFF"),
        "SN": ("#8CC63E", "#FFFFFF"),
        "SR": ("#003D8F", "#FFFFFF"),
        "SW": ("#1D2D5C", "#CC1717"),
        "TL": ("#E6007E", "#FFFFFF"),
        "TP": ("#010385", "#FFFFFF"),
        "VT": ("#004C45", "#FF6B35"),
        "WM": ("#7B2082", "#E86A10"),
        "XP": ("#010385", "#FFFFFF"),
        "XR": ("#6950A1", "#FFFFFF"),
        "XS": ("#003D8F", "#FFFFFF"),
        "ZZ": ("#8E8E93", "#FFFFFF"),   // unknown — neutral grey
    ]

    static func entry(for code: String) -> Entry {
        let pair = table[code] ?? table["ZZ"]!
        let (pr, pg, pb) = rgb(pair.0)
        return Entry(
            primary: Color(red: pr, green: pg, blue: pb),
            secondary: Color(hex: pair.1),
            primaryIsLight: luminance(r: pr, g: pg, b: pb) > 0.30
        )
    }

    private static func rgb(_ hex: String) -> (Double, Double, Double) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        return (Double((int >> 16) & 0xFF) / 255, Double((int >> 8) & 0xFF) / 255, Double(int & 0xFF) / 255)
    }

    /// Relative luminance per WCAG 2.1 (0 = black, 1 = white).
    private static func luminance(r: Double, g: Double, b: Double) -> Double {
        func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }
}

// MARK: - Background views

/// A wide coloured band on the leading edge (~66 pt) behind the time column only.
struct TimePanelBackground: View {
    let colour: Color
    let vibrancy: ColourVibrancy

    var body: some View {
        HStack(spacing: 0) {
            colour.opacity(vibrancy.opacity)
                .frame(width: 66)
            Color(.secondarySystemGroupedBackground)
        }
    }
}

/// A thin 3 pt stripe on the leading edge; the rest is the default background.
struct TracklineBackground: View {
    let colour: Color
    let vibrancy: ColourVibrancy

    var body: some View {
        HStack(spacing: 0) {
            colour.opacity(vibrancy.opacity)
                .frame(width: 3)
            Color(.secondarySystemGroupedBackground)
        }
    }
}

// MARK: - Hex colour initialiser

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
