import XCTest
import SceneKit
@testable import _d_swift_globe_widget

final class GeospatialTests: XCTestCase {
    
    func testLatLonToCartesian() {
        // Test Equator / Prime Meridian (0, 0)
        // Should be at (radius, 0, 0) in SCN space (depending on axis convention)
        // Our implementation: 
        // x = r * cos(lat) * cos(lon)
        // y = r * sin(lat)
        // z = r * cos(lat) * sin(lon)
        
        let pos = GeospatialMath.latLonToCartesian(lat: 0, lon: 0)
        XCTAssertEqual(Float(pos.x), Float(GeospatialMath.earthRadius), accuracy: 0.001)
        XCTAssertEqual(Float(pos.y), 0, accuracy: 0.001)
        XCTAssertEqual(Float(pos.z), 0, accuracy: 0.001)
        
        // Test North Pole (90, 0)
        let northPole = GeospatialMath.latLonToCartesian(lat: 90, lon: 0)
        XCTAssertEqual(Float(northPole.x), 0, accuracy: 0.001)
        XCTAssertEqual(Float(northPole.y), Float(GeospatialMath.earthRadius), accuracy: 0.001)
        XCTAssertEqual(Float(northPole.z), 0, accuracy: 0.001)
    }
    
    func testHaversineDistance() {
        // NYC to LON (~5585 km)
        // Note: earthRadius is normalized to 1.0 in our system
        let nyc = (lat: 40.7128, lon: -74.0060)
        let lon = (lat: 51.5074, lon: -0.1278)
        
        let dist = GeospatialMath.haversineDistance(lat1: nyc.lat, lon1: nyc.lon, lat2: lon.lat, lon2: lon.lon)
        XCTAssertGreaterThan(dist, 0.5) // Distance is in units of earthRadius
        XCTAssertLessThan(dist, 1.5)
    }
}

final class MorphingTests: XCTestCase {
    
    func testMorphInterpolation() {
        // Test midpoint interpolation between NYC and its planar projection
        let lat = 40.7128
        let lon = -74.0060
        
        let spherePos = GeospatialMath.latLonToCartesian(lat: lat, lon: lon)
        let planePos = GeospatialMath.latLonToPlanar(lat: lat, lon: lon)
        
        let mid = MorphingMath.interpolatedPosition(lat: lat, lon: lon, mix: 0.5)
        
        XCTAssertEqual(Float(mid.x), (Float(spherePos.x) + Float(planePos.x)) / 2.0, accuracy: 0.001)
        XCTAssertEqual(Float(mid.y), (Float(spherePos.y) + Float(planePos.y)) / 2.0, accuracy: 0.001)
        XCTAssertEqual(Float(mid.z), (Float(spherePos.z) + Float(planePos.z)) / 2.0, accuracy: 0.001)
    }
}
