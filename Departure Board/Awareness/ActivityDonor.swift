import Foundation
import Intents

final class ActivityDonor {
    static let shared = ActivityDonor()

    private let throttleInterval: TimeInterval = 10 * 60
    private let defaults = SharedDefaults.shared

    private init() {}

    func donateBoardOpen(route: BoardRoute, stationName: String?, filterName: String?, isFavourite: Bool) {
        guard UserDefaults.standard.object(forKey: AwarenessSettingsKeys.siriSuggestionsEnabled) as? Bool ?? true else { return }
        guard shouldDonate(routeID: route.id) else { return }

        let label = stationName ?? route.crs
        let title: String = {
            if let filterName {
                let prefix = route.filterType == "to" ? "to" : "from"
                return "\(label) \(route.boardType == .departures ? "departures" : "arrivals") \(prefix) \(filterName)"
            }
            return "\(label) \(route.boardType == .departures ? "departures" : "arrivals")"
        }()

        donate(
            activityType: isFavourite ? AwarenessActivityType.openFavouriteBoard : AwarenessActivityType.openBoard,
            title: title,
            route: route,
            keywords: [route.crs, route.boardType.rawValue, filterName ?? "", "Departure Board", "Departure Board Pro"]
        )
    }

    func clearDonations() {
        guard let idsData = defaults.data(forKey: AwarenessStorageKeys.donatedActivityIDs),
              let ids = try? JSONDecoder().decode([String].self, from: idsData),
              !ids.isEmpty else {
            defaults.removeObject(forKey: AwarenessStorageKeys.activityThrottleMap)
            defaults.removeObject(forKey: AwarenessStorageKeys.donatedActivityIDs)
            return
        }

        let persistentIDs: [NSUserActivityPersistentIdentifier] = ids.map { id in
            NSUserActivityPersistentIdentifier(id)
        }
        NSUserActivity.deleteSavedUserActivities(withPersistentIdentifiers: persistentIDs) { }
        defaults.removeObject(forKey: AwarenessStorageKeys.activityThrottleMap)
        defaults.removeObject(forKey: AwarenessStorageKeys.donatedActivityIDs)
    }

    private func donate(activityType: String, title: String, route: BoardRoute, keywords: [String]) {
        let activity = NSUserActivity(activityType: activityType)
        activity.title = title
        activity.userInfo = route.userInfo
        activity.isEligibleForPrediction = true
        activity.isEligibleForSearch = true
        activity.suggestedInvocationPhrase = "Open \(route.crs) \(route.boardType == .departures ? "departures" : "arrivals")"

        let persistentID = NSUserActivityPersistentIdentifier("board:\(route.id)")
        activity.persistentIdentifier = persistentID
        activity.targetContentIdentifier = route.id
        activity.keywords = Set(keywords.filter { !$0.isEmpty })
        activity.becomeCurrent()

        var savedIDs: [String] = []
        if let data = defaults.data(forKey: AwarenessStorageKeys.donatedActivityIDs),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            savedIDs = decoded
        }
        if !savedIDs.contains(persistentID) {
            savedIDs.append(persistentID)
            if let data = try? JSONEncoder().encode(savedIDs) {
                defaults.set(data, forKey: AwarenessStorageKeys.donatedActivityIDs)
            }
        }
    }

    private func shouldDonate(routeID: String) -> Bool {
        let now = Date().timeIntervalSince1970
        var map: [String: TimeInterval] = [:]
        if let data = defaults.data(forKey: AwarenessStorageKeys.activityThrottleMap),
           let decoded = try? JSONDecoder().decode([String: TimeInterval].self, from: data) {
            map = decoded
        }

        if let last = map[routeID], now - last < throttleInterval {
            return false
        }

        map[routeID] = now
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: AwarenessStorageKeys.activityThrottleMap)
        }
        return true
    }
}
