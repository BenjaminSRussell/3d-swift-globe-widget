import XCTest
@testable import TitanCore

final class GlobeDataLoaderTests: XCTestCase {
    private func fixture(_ name: String) throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "geojson", subdirectory: "Fixtures"))
    }

    func testParsesFixtureNodesAndEdges() throws {
        let ds = try GlobeDataLoader.load(contentsOf: fixture("sample_network"))
        XCTAssertEqual(ds.nodes.count, 4, "4 Point features; the Polygon is ignored")
        XCTAssertEqual(ds.edges.count, 2)
        XCTAssertEqual(ds.node(id: "nyc")?.name, "New York", "feature-level id is used when properties.id is absent")
        XCTAssertEqual(ds.node(id: "nyc")?.intensity, 8)
        XCTAssertEqual(ds.node(id: "nyc")?.properties["tier"], "1")
        XCTAssertEqual(ds.node(id: "la")?.intensity, 10, "default intensity")
        XCTAssertEqual(ds.edges[0], GlobeEdge(from: "nyc", to: "la", weight: 2))
        XCTAssertEqual(ds.edges[1].from, "lon", "edge without from/to is matched by endpoint coordinates")
        XCTAssertEqual(ds.edges[1].to, "tyo")
        XCTAssertEqual(ds.arcs.count, 2)
    }

    func testBundledDefaultNetworkLoads() throws {
        let ds = try DependencyContainer.bundledDataset()
        XCTAssertEqual(ds.nodes.count, 9)
        XCTAssertEqual(ds.edges.count, 8)
        XCTAssertEqual(ds.nodes.reduce(0) { $0 + $1.intensity }, 140)
    }

    func testNativeFormatAndGeoJSONRoundTrip() throws {
        let original = try GlobeDataLoader.load(contentsOf: fixture("sample_network"))
        let geo = try GlobeDataLoader.load(data: GlobeDataLoader.geoJSON(original))
        XCTAssertEqual(geo.nodes.map(\.id).sorted(), original.nodes.map(\.id).sorted())
        XCTAssertEqual(geo.edges.count, original.edges.count)

        let native = try GlobeDataLoader.load(data: JSONEncoder().encode(original))
        XCTAssertEqual(native, original)
    }

    func testValidationErrors() {
        let unknown = #"{"nodes":[{"id":"a","name":"A","coordinate":{"latitude":0,"longitude":0},"intensity":1,"properties":{}}],"edges":[{"from":"a","to":"zz","weight":1}]}"#
        XCTAssertThrowsError(try GlobeDataLoader.load(data: Data(unknown.utf8))) {
            XCTAssertEqual($0 as? GlobeDataError, .unknownEdgeEndpoint(edge: "a->zz", missing: "zz"))
        }
        let badCoord = #"{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[200,95]},"properties":{"id":"x"}}]}"#
        XCTAssertThrowsError(try GlobeDataLoader.load(data: Data(badCoord.utf8))) {
            XCTAssertEqual($0 as? GlobeDataError, .invalidCoordinate(nodeID: "x"))
        }
        let dup = #"{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[1,1]},"properties":{"id":"x"}},{"type":"Feature","geometry":{"type":"Point","coordinates":[2,2]},"properties":{"id":"x"}}]}"#
        XCTAssertThrowsError(try GlobeDataLoader.load(data: Data(dup.utf8))) {
            XCTAssertEqual($0 as? GlobeDataError, .duplicateNode("x"))
        }
        XCTAssertThrowsError(try GlobeDataLoader.load(data: Data(#"{"type":"Feature"}"#.utf8)))
        XCTAssertThrowsError(try GlobeDataLoader.load(data: Data("nope".utf8)))
    }
}
