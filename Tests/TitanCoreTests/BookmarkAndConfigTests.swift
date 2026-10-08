import XCTest
@testable import TitanCore

final class BookmarkAndConfigTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("titan-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testBookmarksPersistAcrossRelaunch() throws {
        let url = dir.appendingPathComponent("nested/bookmarks.json")
        let tokyo = CameraBookmark(name: "Tokyo", center: GeoCoordinate(latitude: 35.68, longitude: 139.65),
                                   distanceMeters: 1_200_000, pitch: 45, heading: 10)
        let europe = CameraBookmark(name: "Europe", center: GeoCoordinate(latitude: 50, longitude: 8), distanceMeters: 4_000_000)

        // First "launch"
        let first = BookmarkStore(fileURL: url)
        XCTAssertEqual(try first.load(), [], "missing file = no bookmarks")
        try first.add(tokyo)
        try first.add(europe)

        // Second "launch": a fresh store reading the same file
        let second = BookmarkStore(fileURL: url)
        let restored = try second.load()
        XCTAssertEqual(restored.map(\.name), ["Tokyo", "Europe"])
        XCTAssertEqual(restored[0].center, tokyo.center)
        XCTAssertEqual(restored[0].distanceMeters, 1_200_000)
        XCTAssertEqual(restored[0].pitch, 45)

        try second.rename(id: europe.id, to: "EU")
        try second.remove(id: tokyo.id)
        XCTAssertEqual(try BookmarkStore(fileURL: url).load().map(\.name), ["EU"])
    }

    func testSessionExportImportCarriesDatasetAndBookmarks() throws {
        let dataset = try DependencyContainer.bundledDataset()
        let bookmark = CameraBookmark(name: "APAC", center: GeoCoordinate(latitude: 10, longitude: 120), distanceMeters: 9e6)
        let data = try GlobeSession(dataset: dataset, bookmarks: [bookmark]).export()

        let session = try GlobeSession.importSession(data)
        XCTAssertEqual(session.dataset, dataset)
        XCTAssertEqual(session.bookmarks, [bookmark])

        var future = session
        future.version = GlobeSession.currentVersion + 1
        XCTAssertThrowsError(try GlobeSession.importSession(future.export()))
    }

    func testAutoFitFramesAllNodes() throws {
        let dataset = try DependencyContainer.bundledDataset()
        var config = Configuration()
        let camera = config.initialCamera(for: dataset)
        XCTAssertEqual(camera.name, "Auto-fit")
        XCTAssertGreaterThanOrEqual(camera.distanceMeters, config.autoFit.minDistanceMeters)
        XCTAssertLessThanOrEqual(camera.distanceMeters, config.autoFit.maxDistanceMeters)

        let usOnly = GlobeDataset(nodes: dataset.nodes.filter { $0.id.hasPrefix("us-") }, edges: [])
        let usCamera = config.initialCamera(for: usOnly)
        XCTAssertEqual(usCamera.center.latitude, 41, accuracy: 4)
        XCTAssertEqual(usCamera.center.longitude, -106, accuracy: 6)
        XCTAssertLessThan(usCamera.distanceMeters, camera.distanceMeters, "tighter cluster -> closer camera")

        config.autoFit.enabled = false
        XCTAssertEqual(config.initialCamera(for: dataset).center, config.camera.center)
        XCTAssertNil(CameraFraming.fit([]))
    }

    func testEnvironmentOverridesAndContainerFallback() throws {
        let cfg = Configuration.fromEnvironment([
            "TITAN_DATA": "/nonexistent/net.geojson",
            "TITAN_BOOKMARKS": dir.appendingPathComponent("b.json").path,
            "TITAN_AUTOFIT": "0",
            "TITAN_ARC_SECONDS": "1.5",
        ])
        XCTAssertFalse(cfg.autoFit.enabled)
        XCTAssertEqual(cfg.arcs.animationSeconds, 1.5)

        let container = DependencyContainer.makeDefault(configuration: cfg)
        XCTAssertEqual(container.dataset.nodes.count, 9, "bad TITAN_DATA falls back to the bundled sample")
        XCTAssertNotNil(container.dataLoadError)
        XCTAssertEqual(container.bookmarkStore.fileURL.lastPathComponent, "b.json")
    }

    func testContainerLoadsConfiguredFixture() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "sample_network", withExtension: "geojson", subdirectory: "Fixtures"))
        var cfg = Configuration()
        cfg.dataPath = url.path
        let container = DependencyContainer.makeDefault(configuration: cfg)
        XCTAssertNil(container.dataLoadError)
        XCTAssertEqual(container.dataset.nodes.count, 4)
    }
}
