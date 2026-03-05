import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

final class SpotlightIndexer {
    static let shared = SpotlightIndexer()

    private let index = CSSearchableIndex.default()

    private init() {}

    func indexStations(_ stations: [Station]) {
        guard UserDefaults.standard.object(forKey: AwarenessSettingsKeys.spotlightStationsEnabled) as? Bool ?? true else {
            index.deleteSearchableItems(withDomainIdentifiers: ["stations"], completionHandler: nil)
            return
        }

        let items = stations.map { station -> CSSearchableItem in
            let attr = CSSearchableItemAttributeSet(contentType: .content)
            attr.title = station.name
            attr.contentDescription = "\(station.crsCode) departures and arrivals"
            attr.keywords = [station.crsCode, station.name, "departures", "arrivals"]

            let item = CSSearchableItem(
                uniqueIdentifier: AwarenessSearchItem.stationPrefix + station.crsCode,
                domainIdentifier: "stations",
                attributeSet: attr
            )
            item.expirationDate = .distantFuture
            return item
        }

        index.indexSearchableItems(items, completionHandler: nil)
    }

    func indexFavouriteBoards(_ boardIDs: [String], stations: [Station]) {
        guard UserDefaults.standard.object(forKey: AwarenessSettingsKeys.spotlightFavouritesEnabled) as? Bool ?? true else {
            index.deleteSearchableItems(withDomainIdentifiers: ["favourites"], completionHandler: nil)
            return
        }

        index.deleteSearchableItems(withDomainIdentifiers: ["favourites"], completionHandler: nil)

        let stationMap = Dictionary(uniqueKeysWithValues: stations.map { ($0.crsCode, $0) })
        var items: [CSSearchableItem] = []
        for id in boardIDs {
            guard let route = BoardRoute(boardID: id) else { continue }

            let attr = CSSearchableItemAttributeSet(contentType: .content)
            let stationName = stationMap[route.crs]?.name ?? route.crs
            attr.title = "\(stationName) \(route.boardType == .departures ? "Departures" : "Arrivals")"
            if let filterCrs = route.filterCrs {
                let filterName = stationMap[filterCrs]?.name ?? filterCrs
                let direction = route.filterType == "to" ? "to" : "from"
                attr.contentDescription = "Filtered \(direction) \(filterName)"
                attr.keywords = [route.crs, filterCrs, stationName, filterName, "favourite"]
            } else {
                attr.contentDescription = "Favourite board"
                attr.keywords = [route.crs, stationName, "favourite"]
            }

            let item = CSSearchableItem(
                uniqueIdentifier: AwarenessSearchItem.boardPrefix + id,
                domainIdentifier: "favourites",
                attributeSet: attr
            )
            item.expirationDate = .distantFuture
            items.append(item)
        }

        index.indexSearchableItems(items, completionHandler: nil)
    }

    func rebuildAll(stations: [Station], boardIDs: [String]) {
        clearAll()
        indexStations(stations)
        indexFavouriteBoards(boardIDs, stations: stations)
    }

    func clearAll() {
        index.deleteSearchableItems(withDomainIdentifiers: ["stations", "favourites"], completionHandler: nil)
    }

    func deepLink(from userActivity: NSUserActivity) -> DeepLink? {
        if let route = BoardRoute.from(userInfo: userActivity.userInfo) {
            return route.deepLink
        }

        guard userActivity.activityType == CSSearchableItemActionType,
              let id = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return nil
        }

        if id.hasPrefix(AwarenessSearchItem.stationPrefix) {
            let crs = String(id.dropFirst(AwarenessSearchItem.stationPrefix.count))
            return .departures(crs: crs)
        }

        if id.hasPrefix(AwarenessSearchItem.boardPrefix) {
            let boardID = String(id.dropFirst(AwarenessSearchItem.boardPrefix.count))
            return BoardRoute(boardID: boardID)?.deepLink
        }

        return nil
    }
}
