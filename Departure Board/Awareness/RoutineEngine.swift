import Foundation

final class RoutineEngine {
    static let shared = RoutineEngine()

    private let defaults = SharedDefaults.shared
    private let retentionDays = 60
    private let maxEvents = 3000

    private init() {}

    func logBoardOpen(route: BoardRoute) {
        var events = loadEvents()
        events.append(BoardOpenEvent(route: route))

        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? .distantPast
        events = events
            .filter { $0.timestamp >= cutoff }
            .suffix(maxEvents)
            .map { $0 }

        save(events)
    }

    func topLikelyRoutes(now: Date = Date(), limit: Int = 5) -> [BoardRoute] {
        let events = loadEvents()
        guard !events.isEmpty else { return [] }

        let calendar = Calendar.current
        let nowWeekday = calendar.component(.weekday, from: now)
        let nowMinutes = minutesAfterMidnight(now)

        var scores: [String: Double] = [:]
        var latestByRoute: [String: BoardRoute] = [:]

        for event in events {
            let route = event.route
            latestByRoute[event.routeID] = route

            let eventWeekday = calendar.component(.weekday, from: event.timestamp)
            let eventMinutes = minutesAfterMidnight(event.timestamp)
            let diff = abs(eventMinutes - nowMinutes)

            var score = 0.2
            if eventWeekday == nowWeekday { score += 1.0 }
            if diff <= 30 { score += 2.0 }
            else if diff <= 60 { score += 1.0 }

            let ageHours = max(0, now.timeIntervalSince(event.timestamp) / 3600)
            let recencyMultiplier = max(0.2, 1.0 - (ageHours / (24 * 21)))
            scores[event.routeID, default: 0] += score * recencyMultiplier
        }

        return scores
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { latestByRoute[$0.key] }
    }

    func clearHistory() {
        defaults.removeObject(forKey: AwarenessStorageKeys.boardOpenEvents)
    }

    private func loadEvents() -> [BoardOpenEvent] {
        guard let data = defaults.data(forKey: AwarenessStorageKeys.boardOpenEvents),
              let events = try? JSONDecoder().decode([BoardOpenEvent].self, from: data) else {
            return []
        }
        return events
    }

    private func save(_ events: [BoardOpenEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: AwarenessStorageKeys.boardOpenEvents)
        }
    }

    private func minutesAfterMidnight(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
