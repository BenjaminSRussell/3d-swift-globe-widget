// Configuration.swift
import Foundation

/// Engine settings (#3). Value type, injected through `DependencyContainer`.
/// Override at launch with environment variables (see README "Configuration").
public struct Configuration: Codable, Hashable, Sendable {
    public struct Camera: Codable, Hashable, Sendable {
        public var center: GeoCoordinate = GeoCoordinate(latitude: 39.0, longitude: -96.0)
        public var distanceMeters: Double = 8_000_000
        public var pitch: Double = 0
        public var heading: Double = 0
        public init() {}
    }

    public struct AutoFit: Codable, Hashable, Sendable {
        /// Frame the loaded dataset on launch instead of `camera.center`
        public var enabled: Bool = true
        public var padding: Double = 1.3
        public var minDistanceMeters: Double = 500_000
        public var maxDistanceMeters: Double = 30_000_000
        public init() {}
    }

    public struct Arcs: Codable, Hashable, Sendable {
        public var animationSeconds: Double = 3.0
        public var sampleCount: Int = 64
        public init() {}
    }

    public struct Lights: Codable, Hashable, Sendable {
        /// Random scatter (degrees) of server lights around each node
        public var jitterDegrees: Double = 0.5
        public init() {}
    }

    public var camera = Camera()
    public var autoFit = AutoFit()
    public var arcs = Arcs()
    public var lights = Lights()
    /// GeoJSON / native dataset to load; nil = bundled `default_network.geojson`
    public var dataPath: String?
    /// Bookmarks JSON; nil = Application Support/TitanEngine/bookmarks.json
    public var bookmarksPath: String?

    public init() {}

    public static let `default` = Configuration()

    /// `TITAN_DATA`, `TITAN_BOOKMARKS`, `TITAN_AUTOFIT` (0/1), `TITAN_ARC_SECONDS`
    public static func fromEnvironment(_ env: [String: String] = ProcessInfo.processInfo.environment) -> Configuration {
        var c = Configuration()
        if let p = env["TITAN_DATA"], !p.isEmpty { c.dataPath = p }
        if let p = env["TITAN_BOOKMARKS"], !p.isEmpty { c.bookmarksPath = p }
        if let v = env["TITAN_AUTOFIT"] { c.autoFit.enabled = !["0", "false", "no", "off"].contains(v.lowercased()) }
        if let v = env["TITAN_ARC_SECONDS"], let s = Double(v), s > 0 { c.arcs.animationSeconds = s }
        return c
    }

    /// Initial camera: auto-fit to the dataset when enabled and non-empty, else `camera`.
    public func initialCamera(for dataset: GlobeDataset) -> CameraBookmark {
        if autoFit.enabled, let fit = CameraFraming.fit(
            dataset.nodes.map(\.coordinate),
            padding: autoFit.padding,
            minDistance: autoFit.minDistanceMeters,
            maxDistance: autoFit.maxDistanceMeters
        ) {
            return CameraBookmark(name: "Auto-fit", center: fit.center, distanceMeters: fit.distanceMeters,
                                  pitch: camera.pitch, heading: camera.heading)
        }
        return CameraBookmark(name: "Default", center: camera.center, distanceMeters: camera.distanceMeters,
                              pitch: camera.pitch, heading: camera.heading)
    }
}
