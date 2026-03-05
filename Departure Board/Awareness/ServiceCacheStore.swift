import Foundation

struct ServiceCacheKey: Codable {
    let serviceID: String

    fileprivate var fileStem: String {
        serviceID
    }

    fileprivate var fileName: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let safe = fileStem.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(safe) + ".json"
    }
}

final class ServiceCacheStore {
    static let shared = ServiceCacheStore()

    struct CachedServiceSummary: Identifiable {
        let id: String
        let key: ServiceCacheKey
        let loadedAt: Date
        let boardType: BoardType
        let locationName: String
        let scheduled: String
        let originName: String
        let destinationName: String
    }

    private struct CachedServiceEnvelope: Codable {
        let loadedAt: Date
        let key: ServiceCacheKey
        let boardType: BoardType
        let service: Service
        let detail: ServiceDetail
    }

    private let ttl: TimeInterval = 60 * 60
    private let fm = FileManager.default

    private init() {}

    func load(for key: ServiceCacheKey) -> (detail: ServiceDetail, loadedAt: Date)? {
        purgeExpired()

        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(CachedServiceEnvelope.self, from: data) else {
            return nil
        }

        if Date().timeIntervalSince(envelope.loadedAt) > ttl {
            try? fm.removeItem(at: url)
            return nil
        }

        return (envelope.detail, envelope.loadedAt)
    }

    func save(detail: ServiceDetail, for key: ServiceCacheKey, service: Service, boardType: BoardType, loadedAt: Date = Date()) {
        purgeExpired()

        let envelope = CachedServiceEnvelope(
            loadedAt: loadedAt,
            key: key,
            boardType: boardType,
            service: service,
            detail: detail
        )
        guard let data = try? JSONEncoder().encode(envelope) else { return }

        let dir = cacheDirectoryURL()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        purgeVariants(for: key)
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    func listCachedServices() -> [CachedServiceSummary] {
        purgeExpired()

        let dir = cacheDirectoryURL()
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        return files.compactMap { file in
            guard let data = try? Data(contentsOf: file),
                  let envelope = try? JSONDecoder().decode(CachedServiceEnvelope.self, from: data) else {
                return nil
            }
            return CachedServiceSummary(
                id: file.lastPathComponent,
                key: envelope.key,
                loadedAt: envelope.loadedAt,
                boardType: envelope.boardType,
                locationName: envelope.detail.locationName,
                scheduled: envelope.service.scheduled,
                originName: envelope.service.origin.first?.locationName ?? "Unknown",
                destinationName: envelope.service.destination.first?.locationName ?? "Unknown"
            )
        }
        .sorted { $0.loadedAt > $1.loadedAt }
    }

    func clearAll() {
        let dir = cacheDirectoryURL()
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return
        }
        for file in files {
            try? fm.removeItem(at: file)
        }
    }

    func purgeExpired() {
        let dir = cacheDirectoryURL()
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return
        }

        let now = Date()
        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let envelope = try? JSONDecoder().decode(CachedServiceEnvelope.self, from: data) else {
                try? fm.removeItem(at: file)
                continue
            }

            if now.timeIntervalSince(envelope.loadedAt) > ttl {
                try? fm.removeItem(at: file)
            }
        }
    }

    private func fileURL(for key: ServiceCacheKey) -> URL {
        cacheDirectoryURL().appendingPathComponent(key.fileName)
    }

    private func purgeVariants(for key: ServiceCacheKey) {
        let dir = cacheDirectoryURL()
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return
        }
        let prefix = key.fileStem
        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            try? fm.removeItem(at: file)
        }
    }

    private func cacheDirectoryURL() -> URL {
        let root = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return root.appendingPathComponent("ServiceCache", isDirectory: true)
    }
}
