import Foundation

struct BoardRoute: Hashable, Codable, Identifiable {
    let crs: String
    let boardType: BoardType
    let filterCrs: String?
    let filterType: String?

    var id: String {
        SharedDefaults.boardID(crs: crs, boardType: boardType, filterCrs: filterCrs, filterType: filterType)
    }

    init(crs: String, boardType: BoardType, filterCrs: String? = nil, filterType: String? = nil) {
        self.crs = crs.uppercased()
        self.boardType = boardType
        if let filterCrs {
            self.filterCrs = filterCrs.uppercased()
            self.filterType = (filterType == "to") ? "to" : "from"
        } else {
            self.filterCrs = nil
            self.filterType = nil
        }
    }

    init?(boardID: String) {
        guard let parsed = SharedDefaults.parseBoardID(boardID) else { return nil }
        self.init(
            crs: parsed.crs,
            boardType: parsed.boardType,
            filterCrs: parsed.filterCrs,
            filterType: parsed.filterType
        )
    }

    init(destination: StationDestination) {
        self.init(
            crs: destination.station.crsCode,
            boardType: destination.boardType,
            filterCrs: destination.filterStation?.crsCode,
            filterType: destination.filterType
        )
    }

    var deepLink: DeepLink {
        if let filterCrs {
            if boardType == .departures {
                return .filteredDepartures(crs: crs, filterCrs: filterCrs, filterType: filterType == "to" ? "to" : "from")
            }
            return .filteredArrivals(crs: crs, filterCrs: filterCrs, filterType: filterType == "to" ? "to" : "from")
        }
        return boardType == .departures ? .departures(crs: crs) : .arrivals(crs: crs)
    }

    var deepLinkURL: URL {
        var components = URLComponents()
        components.scheme = "departure"
        components.host = boardType == .departures ? "departures" : "arrivals"
        components.path = "/\(crs)"
        if let filterCrs {
            components.queryItems = [
                URLQueryItem(name: "filter", value: filterCrs),
                URLQueryItem(name: "filterType", value: filterType == "to" ? "to" : "from")
            ]
        }
        return components.url ?? URL(string: "departure://departures/\(crs)")!
    }

    static func from(deepLink: DeepLink) -> BoardRoute? {
        switch deepLink {
        case .departures(let crs):
            return BoardRoute(crs: crs, boardType: .departures)
        case .arrivals(let crs):
            return BoardRoute(crs: crs, boardType: .arrivals)
        case .filteredDepartures(let crs, let filterCrs, let filterType):
            return BoardRoute(crs: crs, boardType: .departures, filterCrs: filterCrs, filterType: filterType)
        case .filteredArrivals(let crs, let filterCrs, let filterType):
            return BoardRoute(crs: crs, boardType: .arrivals, filterCrs: filterCrs, filterType: filterType)
        default:
            return nil
        }
    }

    var userInfo: [AnyHashable: Any] {
        var info: [AnyHashable: Any] = [
            AwarenessUserInfoKeys.crs: crs,
            AwarenessUserInfoKeys.boardType: boardType.rawValue,
            AwarenessUserInfoKeys.boardID: id
        ]
        if let filterCrs {
            info[AwarenessUserInfoKeys.filterCrs] = filterCrs
            info[AwarenessUserInfoKeys.filterType] = filterType == "to" ? "to" : "from"
        }
        return info
    }

    static func from(userInfo: [AnyHashable: Any]?) -> BoardRoute? {
        guard let userInfo,
              let crs = userInfo[AwarenessUserInfoKeys.crs] as? String,
              let boardRaw = userInfo[AwarenessUserInfoKeys.boardType] as? String,
              let boardType = BoardType(rawValue: boardRaw) else {
            if let boardID = userInfo?[AwarenessUserInfoKeys.boardID] as? String {
                return BoardRoute(boardID: boardID)
            }
            return nil
        }
        return BoardRoute(
            crs: crs,
            boardType: boardType,
            filterCrs: userInfo[AwarenessUserInfoKeys.filterCrs] as? String,
            filterType: userInfo[AwarenessUserInfoKeys.filterType] as? String
        )
    }

    func displayLabel(stationsByCRS: [String: Station]) -> String {
        let stationName = stationsByCRS[crs]?.name ?? crs
        guard let filterCrs else {
            return "\(stationName) \(boardType == .departures ? "Departures" : "Arrivals")"
        }
        let filterName = stationsByCRS[filterCrs]?.name ?? filterCrs
        let dir = (filterType == "to") ? "->" : "<-"
        return "\(stationName) \(dir) \(filterName)"
    }
}

enum AwarenessActivityType {
    static let openBoard = "com.breslan.departureboard.openBoard"
    static let openFavouriteBoard = "com.breslan.departureboard.openFavouriteBoard"
}

enum AwarenessUserInfoKeys {
    static let crs = "route.crs"
    static let boardType = "route.boardType"
    static let filterCrs = "route.filterCrs"
    static let filterType = "route.filterType"
    static let boardID = "route.boardID"
}

enum AwarenessSearchItem {
    static let stationPrefix = "station:"
    static let boardPrefix = "board:"
}

enum AwarenessSettingsKeys {
    static let siriSuggestionsEnabled = "awarenessSiriSuggestionsEnabled"
    static let spotlightStationsEnabled = "awarenessSpotlightStationsEnabled"
    static let spotlightFavouritesEnabled = "awarenessSpotlightFavouritesEnabled"
}

enum AwarenessStorageKeys {
    static let activityThrottleMap = "awarenessActivityThrottleMap"
    static let donatedActivityIDs = "awarenessDonatedActivityIDs"
    static let boardOpenEvents = "awarenessBoardOpenEvents"
}
