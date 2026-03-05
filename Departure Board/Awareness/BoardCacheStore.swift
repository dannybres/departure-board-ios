import Foundation

struct BoardCacheKey {
    let crs: String
    let boardType: BoardType
    let filterCrs: String?
    let filterType: String?

    fileprivate var fileStem: String {
        [
            crs.uppercased(),
            boardType.rawValue,
            filterCrs?.uppercased() ?? "none",
            filterType ?? "none"
        ].joined(separator: "--")
    }

    fileprivate var fileName: String {
        let raw = fileStem
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let safe = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(safe) + ".json"
    }
}

final class BoardCacheStore {
    static let shared = BoardCacheStore()

    private struct CachedBoardEnvelope: Codable {
        let loadedAt: Date
        let board: DepartureBoard
    }

    private let ttl: TimeInterval = 60 * 60
    private let fm = FileManager.default

    private init() {}

    func load(for key: BoardCacheKey) -> (board: DepartureBoard, loadedAt: Date)? {
        purgeExpired()

        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(CachedBoardEnvelope.self, from: data) else {
            return nil
        }

        if Date().timeIntervalSince(envelope.loadedAt) > ttl {
            try? fm.removeItem(at: url)
            return nil
        }

        return (envelope.board, envelope.loadedAt)
    }

    func save(board: DepartureBoard, for key: BoardCacheKey, loadedAt: Date = Date()) {
        purgeExpired()

        let envelope = CachedBoardEnvelope(loadedAt: loadedAt, board: board)
        guard let data = try? JSONEncoder().encode(envelope) else { return }

        let dir = cacheDirectoryURL()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        purgeVariants(for: key)
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    func purgeExpired() {
        let dir = cacheDirectoryURL()
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return
        }

        let now = Date()
        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let envelope = try? JSONDecoder().decode(CachedBoardEnvelope.self, from: data) else {
                // If a cache file is unreadable/corrupt, remove it.
                try? fm.removeItem(at: file)
                continue
            }

            if now.timeIntervalSince(envelope.loadedAt) > ttl {
                try? fm.removeItem(at: file)
            }
        }
    }

    private func fileURL(for key: BoardCacheKey) -> URL {
        cacheDirectoryURL().appendingPathComponent(key.fileName)
    }

    private func purgeVariants(for key: BoardCacheKey) {
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
        return root.appendingPathComponent("BoardCache", isDirectory: true)
    }
}
