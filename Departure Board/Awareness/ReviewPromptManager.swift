import Foundation
import StoreKit
import UIKit

@MainActor
final class ReviewPromptManager {
    static let shared = ReviewPromptManager()

    struct DebugStats {
        let goodDayStreak: Int
        let lastGoodDay: Date?
        let lastPromptDate: Date?
        let promptYear: Int
        let promptCountThisYear: Int
        let declineCount: Int
        let reviewCompleted: Bool
        let hadBadExperienceThisSession: Bool
        let didPromptThisSession: Bool
        let canPromptNow: Bool
    }

    private enum Keys {
        static let goodDayStreak = "review_good_day_streak"
        static let lastGoodDay = "review_last_good_day"
        static let lastPromptDate = "review_last_prompt_date"
        static let promptYear = "review_prompt_year"
        static let promptCountThisYear = "review_prompt_count_this_year"
        static let declineCount = "review_decline_count"
        static let reviewCompleted = "review_completed"
    }

    private let defaults = UserDefaults.standard
    private let calendar = Calendar.current

    private var hadBadExperienceThisSession = false
    private var didPromptThisSession = false

    private init() {}

    func recordGoodExperience() -> Bool {
        if hadBadExperienceThisSession { return false }

        let today = calendar.startOfDay(for: Date())
        if let last = defaults.object(forKey: Keys.lastGoodDay) as? Date {
            if !calendar.isDate(last, inSameDayAs: today) {
                defaults.set(goodDayStreak + 1, forKey: Keys.goodDayStreak)
                defaults.set(today, forKey: Keys.lastGoodDay)
            }
        } else {
            defaults.set(1, forKey: Keys.goodDayStreak)
            defaults.set(today, forKey: Keys.lastGoodDay)
        }

        return goodDayStreak >= 5 && canPromptNow
    }

    func recordBadExperience() {
        hadBadExperienceThisSession = true
        defaults.set(0, forKey: Keys.goodDayStreak)
    }

    func handlePositiveReviewResponse() {
        recordPromptAttempt()
        defaults.set(true, forKey: Keys.reviewCompleted)
        requestSystemReview()
    }

    func handleNegativeReviewResponse() {
        recordPromptAttempt()
        defaults.set(declineCount + 1, forKey: Keys.declineCount)
    }

    func forceRequestReviewForDebug() {
        requestSystemReview()
    }

    func resetForDebug() {
        defaults.removeObject(forKey: Keys.goodDayStreak)
        defaults.removeObject(forKey: Keys.lastGoodDay)
        defaults.removeObject(forKey: Keys.lastPromptDate)
        defaults.removeObject(forKey: Keys.promptYear)
        defaults.removeObject(forKey: Keys.promptCountThisYear)
        defaults.removeObject(forKey: Keys.declineCount)
        defaults.removeObject(forKey: Keys.reviewCompleted)
        hadBadExperienceThisSession = false
        didPromptThisSession = false
    }

    var debugStats: DebugStats {
        DebugStats(
            goodDayStreak: goodDayStreak,
            lastGoodDay: defaults.object(forKey: Keys.lastGoodDay) as? Date,
            lastPromptDate: defaults.object(forKey: Keys.lastPromptDate) as? Date,
            promptYear: promptYear,
            promptCountThisYear: promptCountThisYear,
            declineCount: declineCount,
            reviewCompleted: reviewCompleted,
            hadBadExperienceThisSession: hadBadExperienceThisSession,
            didPromptThisSession: didPromptThisSession,
            canPromptNow: canPromptNow
        )
    }

    var canPromptNow: Bool {
        guard !reviewCompleted else { return false }
        guard declineCount < 5 else { return false }
        guard !didPromptThisSession else { return false }

        if let lastPromptDate = defaults.object(forKey: Keys.lastPromptDate) as? Date {
            if Date().timeIntervalSince(lastPromptDate) < (120 * 24 * 60 * 60) {
                return false
            }
        }

        let year = calendar.component(.year, from: Date())
        if promptYear == year {
            return promptCountThisYear < 3
        }

        return true
    }

    private var goodDayStreak: Int {
        defaults.integer(forKey: Keys.goodDayStreak)
    }

    private var declineCount: Int {
        defaults.integer(forKey: Keys.declineCount)
    }

    private var reviewCompleted: Bool {
        defaults.bool(forKey: Keys.reviewCompleted)
    }

    private var promptYear: Int {
        defaults.integer(forKey: Keys.promptYear)
    }

    private var promptCountThisYear: Int {
        defaults.integer(forKey: Keys.promptCountThisYear)
    }

    private func recordPromptAttempt() {
        let year = calendar.component(.year, from: Date())
        if promptYear != year {
            defaults.set(year, forKey: Keys.promptYear)
            defaults.set(1, forKey: Keys.promptCountThisYear)
        } else {
            defaults.set(promptCountThisYear + 1, forKey: Keys.promptCountThisYear)
        }

        defaults.set(Date(), forKey: Keys.lastPromptDate)
        defaults.set(0, forKey: Keys.goodDayStreak)
        didPromptThisSession = true
    }

    private func requestSystemReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        SKStoreReviewController.requestReview(in: scene)
    }
}
