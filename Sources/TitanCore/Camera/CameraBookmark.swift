import Foundation

/// A saved camera framing (#5). `distanceMeters` is the eye distance from the centre point.
public struct CameraBookmark: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var center: GeoCoordinate
    public var distanceMeters: Double
    public var pitch: Double
    public var heading: Double
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        center: GeoCoordinate,
        distanceMeters: Double,
        pitch: Double = 0,
        heading: Double = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.center = center
        self.distanceMeters = distanceMeters
        self.pitch = pitch
        self.heading = heading
        // Whole seconds: the JSON file uses ISO 8601, so this round-trips exactly
        self.createdAt = Date(timeIntervalSince1970: createdAt.timeIntervalSince1970.rounded(.down))
    }
}

/// Persists bookmarks as JSON so they survive relaunch.
/// Default location: `~/Library/Application Support/TitanEngine/bookmarks.json`
/// (override with `Configuration.bookmarksPath` / `TITAN_BOOKMARKS`).
public struct BookmarkStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("TitanEngine", isDirectory: true).appendingPathComponent("bookmarks.json")
    }

    /// Saved bookmarks, oldest first. A missing file is an empty list.
    public func load() throws -> [CameraBookmark] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try GlobeSession.decoder.decode([CameraBookmark].self, from: Data(contentsOf: fileURL))
    }

    /// Atomically replace the stored bookmarks
    public func save(_ bookmarks: [CameraBookmark]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try GlobeSession.encoder.encode(bookmarks).write(to: fileURL, options: .atomic)
    }

    @discardableResult
    public func add(_ bookmark: CameraBookmark) throws -> [CameraBookmark] {
        var all = try load()
        all.append(bookmark)
        try save(all)
        return all
    }

    @discardableResult
    public func remove(id: UUID) throws -> [CameraBookmark] {
        let all = try load().filter { $0.id != id }
        try save(all)
        return all
    }

    @discardableResult
    public func rename(id: UUID, to name: String) throws -> [CameraBookmark] {
        var all = try load()
        if let i = all.firstIndex(where: { $0.id == id }) { all[i].name = name }
        try save(all)
        return all
    }
}

/// Everything needed to restore a layout elsewhere: the GeoJSON-loadable dataset plus bookmarks (#5).
/// Export with `GlobeSession.export`, import with `GlobeSession.importSession`.
public struct GlobeSession: Codable, Hashable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var dataset: GlobeDataset
    public var bookmarks: [CameraBookmark]

    public init(dataset: GlobeDataset, bookmarks: [CameraBookmark], version: Int = GlobeSession.currentVersion) {
        self.version = version
        self.dataset = dataset
        self.bookmarks = bookmarks
    }

    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    public func export() throws -> Data { try Self.encoder.encode(self) }

    public static func importSession(_ data: Data) throws -> GlobeSession {
        let session = try decoder.decode(GlobeSession.self, from: data)
        guard session.version <= currentVersion else {
            throw GlobeDataError.unsupportedFormat("session version \(session.version)")
        }
        try GlobeDataLoader.validate(session.dataset)
        return session
    }
}

/// Auto-fit: a camera framing that shows every coordinate (#3 "camera/auto-fit knobs").
public enum CameraFraming {
    /// Centre = normalized mean of the unit vectors; distance grows with the widest angular spread.
    public static func fit(
        _ coordinates: [GeoCoordinate],
        padding: Double = 1.3,
        minDistance: Double = 500_000,
        maxDistance: Double = 30_000_000
    ) -> (center: GeoCoordinate, distanceMeters: Double)? {
        guard !coordinates.isEmpty else { return nil }
        var sx = 0.0, sy = 0.0, sz = 0.0
        for c in coordinates {
            let p = GeoMath.cartesian(c)
            sx += p.x; sy += p.y; sz += p.z
        }
        let mean = Cartesian3(x: sx, y: sy, z: sz)
        // Points spread around the whole globe cancel out: fall back to the first point.
        let center = mean.length < 1e-9 ? coordinates[0] : GeoMath.coordinate(mean)
        let spread = coordinates.map { GeoMath.centralAngle(center, $0) }.max() ?? 0
        let distance = spread * GeoMath.earthRadiusMeters * 2 * padding
        return (center, min(maxDistance, max(minDistance, distance)))
    }
}
