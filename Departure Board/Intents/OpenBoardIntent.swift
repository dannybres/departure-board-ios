import Foundation
import AppIntents

struct OpenBoardIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Board"
    static var description = IntentDescription("Open a departures or arrivals board for a selected station.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Station")
    var station: StationEntity

    @Parameter(title: "Board Type", default: .departures)
    var boardType: IntentBoardType

    @Parameter(title: "Filter Station")
    var filterStation: StationEntity?

    @Parameter(title: "Filter Direction")
    var filterDirection: IntentFilterDirection?

    func perform() async throws -> some IntentResult {
        var components = URLComponents()
        components.scheme = "departure"
        components.host = boardType.boardType == .departures ? "departures" : "arrivals"
        components.path = "/\(station.id.uppercased())"
        if let filterStation {
            components.queryItems = [
                URLQueryItem(name: "filter", value: filterStation.id.uppercased()),
                URLQueryItem(name: "filterType", value: filterDirection?.rawValue ?? "to")
            ]
        }
        let url = components.url ?? URL(string: "departure://departures/\(station.id.uppercased())")!
        await MainActor.run { SharedDefaults.setPendingIntentDeepLinkURL(url) }
        return .result()
    }
}

struct OpenFavouriteBoardIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Favourite Board"
    static var description = IntentDescription("Open one of your saved favourite boards.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Favourite")
    var favourite: FavouriteBoardEntity

    func perform() async throws -> some IntentResult {
        let gateURL = URL(string: "departure://pro/shortcuts")!
        guard let parsed = await MainActor.run(body: { SharedDefaults.parseBoardID(favourite.id) }) else {
            await MainActor.run { SharedDefaults.setPendingIntentDeepLinkURL(gateURL) }
            return .result()
        }

        var components = URLComponents()
        components.scheme = "departure"
        components.host = parsed.boardType == .departures ? "departures" : "arrivals"
        components.path = "/\(parsed.crs.uppercased())"
        if let filter = parsed.filterCrs {
            components.queryItems = [
                URLQueryItem(name: "filter", value: filter.uppercased()),
                URLQueryItem(name: "filterType", value: parsed.filterType == "to" ? "to" : "from")
            ]
        }
        let url = components.url ?? URL(string: "departure://departures/\(parsed.crs.uppercased())")!
        await MainActor.run { SharedDefaults.setPendingIntentDeepLinkURL(url) }
        return .result()
    }
}
