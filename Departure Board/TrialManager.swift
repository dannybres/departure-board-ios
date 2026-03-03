//
//  TrialManager.swift
//  Departure Board
//

import Foundation
import Security
import Combine

/// Manages the 28-day free trial, persisting first-launch date in the Keychain
/// so it cannot be reset by clearing UserDefaults.
final class TrialManager: ObservableObject {

    static let shared = TrialManager()

    /// Total trial length in days.
    static let trialDays = 28

    private static let keychainService = "uk.co.danielbreslan.DepartureBoard"
    private static let keychainAccount = "firstLaunchDate"

    /// First launch date, stored once in the Keychain and never changed (except via resetForDebug).
    @Published private(set) var firstLaunchDate: Date

    /// How many whole days remain in the trial (0 when expired).
    @Published private(set) var daysRemaining: Int

    /// Whether the trial has expired.
    @Published private(set) var isExpired: Bool

    private init() {
        let stored = Self.loadFromKeychain() ?? {
            let now = Date()
            Self.saveToKeychain(now)
            return now
        }()
        firstLaunchDate = stored

        let elapsed = Calendar.current.dateComponents([.day], from: stored, to: Date()).day ?? 0
        let remaining = max(0, Self.trialDays - elapsed)
        daysRemaining = remaining
        isExpired = remaining == 0
    }

    // MARK: - Debug

    /// Shifts the stored first-launch date by `days` (negative = further back, positive = forward).
    func shiftForDebug(days: Int) {
        let shifted = Calendar.current.date(byAdding: .day, value: days, to: firstLaunchDate) ?? firstLaunchDate
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: Self.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        Self.saveToKeychain(shifted)
        firstLaunchDate = shifted
        let elapsed = Calendar.current.dateComponents([.day], from: shifted, to: Date()).day ?? 0
        let remaining = max(0, Self.trialDays - elapsed)
        daysRemaining = remaining
        isExpired = remaining == 0
    }

    /// Deletes the Keychain entry and resets the trial to today. Debug builds only.
    func resetForDebug() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: Self.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        let now = Date()
        Self.saveToKeychain(now)
        firstLaunchDate = now
        daysRemaining = Self.trialDays
        isExpired = false
    }

    // MARK: - Keychain helpers

    private static func loadFromKeychain() -> Date? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      keychainService,
            kSecAttrAccount:      keychainAccount,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let interval = try? JSONDecoder().decode(TimeInterval.self, from: data) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    private static func saveToKeychain(_ date: Date) {
        guard let data = try? JSONEncoder().encode(date.timeIntervalSince1970) else { return }
        let attributes: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecValueData:   data
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
