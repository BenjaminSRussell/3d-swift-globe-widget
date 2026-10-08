import Foundation

/// A point on the globe (server hub, PoP, data centre)
public struct GlobeNode: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var coordinate: GeoCoordinate
    /// Number of "server lights" to scatter around the node (visual weight)
    public var intensity: Int
    /// Free-form properties carried through from GeoJSON for the detail panel
    public var properties: [String: String]

    public init(id: String, name: String, coordinate: GeoCoordinate, intensity: Int = 10, properties: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.intensity = intensity
        self.properties = properties
    }
}

/// A connection (arc) between two nodes
public struct GlobeEdge: Codable, Hashable, Sendable, Identifiable {
    public var from: String
    public var to: String
    public var weight: Double

    public var id: String { "\(from)->\(to)" }

    public init(from: String, to: String, weight: Double = 1) {
        self.from = from
        self.to = to
        self.weight = weight
    }
}

/// Nodes + edges to draw on the globe
public struct GlobeDataset: Codable, Hashable, Sendable {
    public var nodes: [GlobeNode]
    public var edges: [GlobeEdge]

    public init(nodes: [GlobeNode], edges: [GlobeEdge]) {
        self.nodes = nodes
        self.edges = edges
    }

    public static let empty = GlobeDataset(nodes: [], edges: [])

    public func node(id: String) -> GlobeNode? { nodes.first { $0.id == id } }

    /// Edge endpoints resolved to coordinates (edges validated at load time, so all resolve)
    public var arcs: [(from: GlobeNode, to: GlobeNode, edge: GlobeEdge)] {
        let byID = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return edges.compactMap { e in
            guard let a = byID[e.from], let b = byID[e.to] else { return nil }
            return (a, b, e)
        }
    }
}

public enum GlobeDataError: Error, Equatable, CustomStringConvertible {
    case unsupportedFormat(String)
    case invalidCoordinate(nodeID: String)
    case duplicateNode(String)
    case unknownEdgeEndpoint(edge: String, missing: String)
    case malformed(String)

    public var description: String {
        switch self {
        case .unsupportedFormat(let s): return "Unsupported data format: \(s)"
        case .invalidCoordinate(let id): return "Node \(id) has an invalid coordinate"
        case .duplicateNode(let id): return "Duplicate node id \(id)"
        case .unknownEdgeEndpoint(let edge, let missing): return "Edge \(edge) references unknown node \(missing)"
        case .malformed(let s): return "Malformed data: \(s)"
        }
    }
}

/// Loads globe data from either
/// - **GeoJSON** `FeatureCollection`: `Point` features are nodes (`properties.id`, `name`,
///   `intensity`); `LineString` features are edges (`properties.from`/`to`, or endpoints matched to
///   node coordinates), or
/// - the **native** format `{"nodes": [...], "edges": [...]}` (`GlobeDataset` Codable).
public enum GlobeDataLoader {
    public static func load(contentsOf url: URL) throws -> GlobeDataset {
        try load(data: Data(contentsOf: url))
    }

    public static func load(data: Data) throws -> GlobeDataset {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw GlobeDataError.malformed("not JSON (\(error.localizedDescription))")
        }
        guard let root = object as? [String: Any] else { throw GlobeDataError.malformed("top level must be an object") }

        let dataset: GlobeDataset
        if let type = root["type"] as? String {
            guard type == "FeatureCollection" else { throw GlobeDataError.unsupportedFormat("GeoJSON type \(type)") }
            dataset = try parseGeoJSON(root)
        } else if root["nodes"] != nil {
            do {
                dataset = try JSONDecoder().decode(GlobeDataset.self, from: data)
            } catch {
                throw GlobeDataError.malformed("native dataset: \(error)")
            }
        } else {
            throw GlobeDataError.unsupportedFormat("expected a GeoJSON FeatureCollection or {nodes, edges}")
        }
        try validate(dataset)
        return dataset
    }

    public static func validate(_ dataset: GlobeDataset) throws {
        var seen = Set<String>()
        for node in dataset.nodes {
            guard seen.insert(node.id).inserted else { throw GlobeDataError.duplicateNode(node.id) }
            guard node.coordinate.isValid else { throw GlobeDataError.invalidCoordinate(nodeID: node.id) }
        }
        for edge in dataset.edges {
            for end in [edge.from, edge.to] where !seen.contains(end) {
                throw GlobeDataError.unknownEdgeEndpoint(edge: edge.id, missing: end)
            }
        }
    }

    /// Serialise as GeoJSON (round-trips through `load(data:)`)
    public static func geoJSON(_ dataset: GlobeDataset) throws -> Data {
        var features: [[String: Any]] = dataset.nodes.map { n in
            var props: [String: Any] = n.properties
            props["id"] = n.id
            props["name"] = n.name
            props["intensity"] = n.intensity
            return ["type": "Feature",
                    "geometry": ["type": "Point", "coordinates": [n.coordinate.longitude, n.coordinate.latitude]],
                    "properties": props]
        }
        let byID = Dictionary(dataset.nodes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for e in dataset.edges {
            guard let a = byID[e.from], let b = byID[e.to] else { continue }
            features.append(["type": "Feature",
                             "geometry": ["type": "LineString",
                                          "coordinates": [[a.coordinate.longitude, a.coordinate.latitude],
                                                          [b.coordinate.longitude, b.coordinate.latitude]]],
                             "properties": ["from": e.from, "to": e.to, "weight": e.weight]])
        }
        return try JSONSerialization.data(withJSONObject: ["type": "FeatureCollection", "features": features],
                                          options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - GeoJSON

    private static func position(_ any: Any?) -> GeoCoordinate? {
        guard let arr = any as? [Any], arr.count >= 2,
              let lon = (arr[0] as? NSNumber)?.doubleValue, let lat = (arr[1] as? NSNumber)?.doubleValue else { return nil }
        return GeoCoordinate(latitude: lat, longitude: lon)
    }

    private static func string(_ any: Any?) -> String? {
        if let s = any as? String { return s }
        if let n = any as? NSNumber { return n.stringValue }
        return nil
    }

    private static func parseGeoJSON(_ root: [String: Any]) throws -> GlobeDataset {
        guard let features = root["features"] as? [[String: Any]] else {
            throw GlobeDataError.malformed("FeatureCollection without features")
        }
        var nodes: [GlobeNode] = []
        var lines: [(props: [String: Any], coords: [GeoCoordinate], index: Int)] = []

        for (i, feature) in features.enumerated() {
            guard let geometry = feature["geometry"] as? [String: Any], let type = geometry["type"] as? String else {
                throw GlobeDataError.malformed("feature \(i) has no geometry")
            }
            let props = feature["properties"] as? [String: Any] ?? [:]
            switch type {
            case "Point":
                guard let c = position(geometry["coordinates"]) else { throw GlobeDataError.malformed("feature \(i) Point coordinates") }
                let id = string(props["id"]) ?? string(feature["id"]) ?? "node-\(i)"
                var extra: [String: String] = [:]
                for (k, v) in props where !["id", "name", "intensity"].contains(k) {
                    if let s = string(v) { extra[k] = s }
                }
                nodes.append(GlobeNode(
                    id: id,
                    name: string(props["name"]) ?? id,
                    coordinate: c,
                    intensity: (props["intensity"] as? NSNumber)?.intValue ?? 10,
                    properties: extra
                ))
            case "LineString":
                guard let raw = geometry["coordinates"] as? [Any] else { throw GlobeDataError.malformed("feature \(i) LineString coordinates") }
                lines.append((props, raw.compactMap(position), i))
            default:
                continue  // Polygons etc. are ignored for now
            }
        }

        // Edges: explicit from/to, else match line endpoints to the nearest node within ~1 km
        func nearest(_ c: GeoCoordinate) -> String? {
            nodes.min { GeoMath.distanceMeters($0.coordinate, c) < GeoMath.distanceMeters($1.coordinate, c) }
                .flatMap { GeoMath.distanceMeters($0.coordinate, c) < 1_000 ? $0.id : nil }
        }
        var edges: [GlobeEdge] = []
        for line in lines {
            let weight = (line.props["weight"] as? NSNumber)?.doubleValue ?? 1
            if let from = string(line.props["from"]), let to = string(line.props["to"]) {
                edges.append(GlobeEdge(from: from, to: to, weight: weight))
            } else if let first = line.coords.first, let last = line.coords.last,
                      let from = nearest(first), let to = nearest(last) {
                edges.append(GlobeEdge(from: from, to: to, weight: weight))
            } else {
                throw GlobeDataError.malformed("feature \(line.index): LineString needs properties.from/to or endpoints at nodes")
            }
        }
        return GlobeDataset(nodes: nodes, edges: edges)
    }
}
