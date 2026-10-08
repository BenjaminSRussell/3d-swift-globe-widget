import XCTest
@testable import TitanCore

final class GeoMathTests: XCTestCase {
    func testCartesianProjectionOfKnownPoints() {
        let origin = GeoMath.cartesian(GeoCoordinate(latitude: 0, longitude: 0))
        XCTAssertEqual(origin.x, 1, accuracy: 1e-12)
        XCTAssertEqual(origin.y, 0, accuracy: 1e-12)
        XCTAssertEqual(origin.z, 0, accuracy: 1e-12)

        let north = GeoMath.cartesian(GeoCoordinate(latitude: 90, longitude: 123), radius: 2)
        XCTAssertEqual(north.z, 2, accuracy: 1e-12)
        XCTAssertEqual(hypot(north.x, north.y), 0, accuracy: 1e-12)

        let east = GeoMath.cartesian(GeoCoordinate(latitude: 0, longitude: 90))
        XCTAssertEqual(east.y, 1, accuracy: 1e-12)
    }

    func testCartesianRoundTrip() {
        for c in [GeoCoordinate(latitude: 40.7128, longitude: -74.006), GeoCoordinate(latitude: -33.8688, longitude: 151.2093)] {
            let back = GeoMath.coordinate(GeoMath.cartesian(c, radius: 6_371))
            XCTAssertEqual(back.latitude, c.latitude, accuracy: 1e-9)
            XCTAssertEqual(back.longitude, c.longitude, accuracy: 1e-9)
        }
    }

    func testGreatCircleDistanceNYCToLA() {
        let nyc = GeoCoordinate(latitude: 40.7128, longitude: -74.0060)
        let la = GeoCoordinate(latitude: 34.0522, longitude: -118.2437)
        // Published great-circle distance ≈ 3,936 km
        XCTAssertEqual(GeoMath.distanceMeters(nyc, la) / 1000, 3936, accuracy: 15)
        XCTAssertEqual(GeoMath.distanceMeters(nyc, nyc), 0, accuracy: 1e-6)
    }

    func testArcSamplingStaysOnGreatCircleAndIsEvenlySpaced() {
        let a = GeoCoordinate(latitude: 51.5072, longitude: -0.1276)
        let b = GeoCoordinate(latitude: 35.6762, longitude: 139.6503)
        let points = GeoMath.sampleArc(from: a, to: b, count: 33)
        XCTAssertEqual(points.count, 33)
        XCTAssertEqual(points.first!.latitude, a.latitude, accuracy: 1e-9)
        XCTAssertEqual(points.last!.longitude, b.longitude, accuracy: 1e-9)

        let total = GeoMath.distanceMeters(a, b)
        let step = total / 32
        for (p, q) in zip(points, points.dropFirst()) {
            XCTAssertEqual(GeoMath.distanceMeters(p, q), step, accuracy: 1)  // evenly spaced
        }
        // Every sample lies on the great circle: d(a,p) + d(p,b) == d(a,b)
        for p in points {
            XCTAssertEqual(GeoMath.distanceMeters(a, p) + GeoMath.distanceMeters(p, b), total, accuracy: 1)
        }
        // London→Tokyo great circle passes well north of both endpoints
        XCTAssertGreaterThan(points[16].latitude, 60)
    }

    func testArcAltitudePeaksMidwayAndScalesWithLength() {
        XCTAssertEqual(GeoMath.arcAltitude(fraction: 0, centralAngle: 1), 0, accuracy: 1e-12)
        XCTAssertEqual(GeoMath.arcAltitude(fraction: 1, centralAngle: 1), 0, accuracy: 1e-12)
        XCTAssertGreaterThan(GeoMath.arcAltitude(fraction: 0.5, centralAngle: 2),
                             GeoMath.arcAltitude(fraction: 0.5, centralAngle: 0.2))
    }

    func testSampleArcDegenerateCounts() {
        let a = GeoCoordinate(latitude: 1, longitude: 2)
        XCTAssertEqual(GeoMath.sampleArc(from: a, to: a, count: 0), [])
        XCTAssertEqual(GeoMath.sampleArc(from: a, to: a, count: 1), [a])
    }
}
