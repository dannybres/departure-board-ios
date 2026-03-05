import Foundation

enum WebShareURL {
    static var baseURL: URL? {
        guard var components = URLComponents(string: APIConfig.baseURL) else { return nil }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }

    static func boardURL(crs: String, boardType: BoardType, filterCrs: String? = nil, filterType: String? = nil) -> URL? {
        guard let baseURL, var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }

        let upperCRS = crs.uppercased()
        var path: String
        switch boardType {
        case .departures:
            path = "/departures/\(upperCRS)"
            if let filterCrs {
                let segment = (filterType == "from") ? "from" : "to"
                path += "/\(segment)/\(filterCrs.uppercased())"
            }
        case .arrivals:
            path = "/arrivals/\(upperCRS)"
            if let filterCrs {
                let segment = (filterType == "to") ? "to" : "from"
                path += "/\(segment)/\(filterCrs.uppercased())"
            }
        }

        components.path = path
        components.queryItems = nil
        return components.url
    }

    static func serviceURL(serviceID: String) -> URL? {
        guard let baseURL, var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        components.path = "/service/\(serviceID)"
        return components.url
    }
}
