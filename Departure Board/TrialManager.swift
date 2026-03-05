//
//  TrialManager.swift
//  Departure Board
//

import Foundation
import Security
import Combine
import WidgetKit

/// Manages the 28-day free trial, persisting first-launch date in the Keychain
/// so it cannot be reset by clearing UserDefaults.
final class TrialManager: ObservableObject {

    static let shared = TrialManager()

    /// Total trial length in days.
    static let trialDays = 28

    private static let keychainService = "uk.co.danielbreslan.DepartureBoard"
    private static let keychainAccount = "firstLaunchDate"
    private static let secondTrialAccount = "secondTrialUsed"

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
        Self.overwriteFirstLaunchDate(shifted)
        refreshTrialState(from: shifted)
    }

    /// Deletes the Keychain entry and resets the trial to today. Debug builds only.
    func resetForDebug() {
        let now = Date()
        Self.overwriteFirstLaunchDate(now)
        Self.saveSecondTrialUsed(false)
        refreshTrialState(from: now)
    }

    /// Clears only the second-trial-used marker so support-code redemption can be tested again.
    func resetSecondTrialForDebug() {
        Self.saveSecondTrialUsed(false)
    }

    /// True when the one-time second trial has already been consumed.
    func hasUsedSecondTrial() -> Bool {
        Self.loadSecondTrialUsed()
    }

    /// Redeems the one-time second trial by setting first launch date to now.
    /// Returns false if the second trial was already used.
    @discardableResult
    func redeemSecondTrialIfAvailable() -> Bool {
        guard !Self.loadSecondTrialUsed() else { return false }
        let now = Date()
        Self.overwriteFirstLaunchDate(now)
        Self.saveSecondTrialUsed(true)
        refreshTrialState(from: now)
        return true
    }

    // MARK: - Keychain helpers

    private static func loadFromKeychain() -> Date? {
        guard let data = loadDataFromKeychain(account: keychainAccount),
              let interval = try? JSONDecoder().decode(TimeInterval.self, from: data) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    private static func saveToKeychain(_ date: Date) {
        guard let data = try? JSONEncoder().encode(date.timeIntervalSince1970) else { return }
        saveDataToKeychain(account: keychainAccount, data: data)
    }

    private func refreshTrialState(from date: Date) {
        firstLaunchDate = date
        let elapsed = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        let remaining = max(0, Self.trialDays - elapsed)
        daysRemaining = remaining
        isExpired = remaining == 0
    }

    private static func overwriteFirstLaunchDate(_ date: Date) {
        deleteKeychainItem(account: keychainAccount)
        saveToKeychain(date)
    }

    private static func loadSecondTrialUsed() -> Bool {
        guard let data = loadDataFromKeychain(account: secondTrialAccount) else { return false }
        return (try? JSONDecoder().decode(Bool.self, from: data)) ?? false
    }

    private static func saveSecondTrialUsed(_ used: Bool) {
        if used {
            guard let data = try? JSONEncoder().encode(true) else { return }
            saveDataToKeychain(account: secondTrialAccount, data: data)
        } else {
            deleteKeychainItem(account: secondTrialAccount)
        }
    }

    private static func loadDataFromKeychain(account: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      keychainService,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    private static func saveDataToKeychain(account: String, data: Data) {
        deleteKeychainItem(account: account)
        let attributes: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: account,
            kSecValueData:   data
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func deleteKeychainItem(account: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
final class EntitlementManager: ObservableObject {
    static let shared = EntitlementManager()

    @Published private(set) var hasSubscription: Bool
    @Published private(set) var hasPremiumAccess: Bool = false

    private var cancellables: Set<AnyCancellable> = []
    private let trial = TrialManager.shared

    private init() {
        hasSubscription = UserDefaults.standard.bool(forKey: SharedDefaults.Keys.hasActiveSubscription)
        recomputeAndPersist()

        trial.$isExpired
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recomputeAndPersist()
            }
            .store(in: &cancellables)
    }

    var isTrialActive: Bool {
        !trial.isExpired
    }

    func setSubscriptionActive(_ active: Bool) {
        guard hasSubscription != active else { return }
        hasSubscription = active
        UserDefaults.standard.set(active, forKey: SharedDefaults.Keys.hasActiveSubscription)
        recomputeAndPersist()
    }

    private func recomputeAndPersist() {
        let newValue = isTrialActive || hasSubscription
        guard hasPremiumAccess != newValue
                || SharedDefaults.shared.object(forKey: SharedDefaults.Keys.premiumAccessSnapshot) == nil else { return }
        hasPremiumAccess = newValue
        SharedDefaults.shared.set(newValue, forKey: SharedDefaults.Keys.premiumAccessSnapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
