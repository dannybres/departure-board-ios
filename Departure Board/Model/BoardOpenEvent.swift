import Foundation

struct BoardOpenEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let routeID: String
    let crs: String
    let boardType: BoardType
    let filterCrs: String?
    let filterType: String?
    let timestamp: Date

    init(route: BoardRoute, timestamp: Date = Date()) {
        self.id = UUID()
        self.routeID = route.id
        self.crs = route.crs
        self.boardType = route.boardType
        self.filterCrs = route.filterCrs
        self.filterType = route.filterType
        self.timestamp = timestamp
    }

    var route: BoardRoute {
        BoardRoute(crs: crs, boardType: boardType, filterCrs: filterCrs, filterType: filterType)
    }
}
