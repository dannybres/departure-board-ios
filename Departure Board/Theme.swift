//
//  Theme.swift
//  Departure Board
//

import SwiftUI

// MARK: - Station Name Environment Key

struct StationNamesSmallCapsKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var stationNamesSmallCaps: Bool {
        get { self[StationNamesSmallCapsKey.self] }
        set { self[StationNamesSmallCapsKey.self] = newValue }
    }
}

extension Font {
    func smallCapsIfEnabled(_ enabled: Bool) -> Font {
        enabled ? self.lowercaseSmallCaps() : self
    }
}

// MARK: - Theme

enum Theme {
    static let brand = Color(red: 66/255, green: 149/255, blue: 180/255)
    static let brandDeep = Color(red: 40/255, green: 100/255, blue: 130/255)
    static let brandSubtle = brand.opacity(0.10)

    static let platformBadge = Color(white: 0.2)
    static let platformBadgeDark = Color(white: 0.85)

    static let timeFont: Font = .system(.subheadline, design: .monospaced).bold()
    static let crsFont: Font = .system(.caption, design: .monospaced).bold()

    static let rowPadding: CGFloat = 4
}
