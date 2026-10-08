import Foundation

/// A latitude/longitude pair in degrees. Platform-neutral (no CoreLocation) so it is unit-testable anywhere.
public struct GeoCoordinate: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Valid WGS84 range
    public var isValid: Bool {
        (-90.0...90.0).contains(latitude) && (-180.0...180.0).contains(longitude)
            && latitude.isFinite && longitude.isFinite
    }
}

/// Cartesian point on (or above) a sphere centred at the origin. +Z is the north pole,
/// +X points at (0°, 0°), +Y at (0°, 90°E).
public struct Cartesian3: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var length: Double { (x * x + y * y + z * z).squareRoot() }
}

/// Spherical geometry used by the globe: projection, distances and arc sampling.
public enum GeoMath {
    /// Mean Earth radius in metres (IUGG)
    public static let earthRadiusMeters: Double = 6_371_008.8

    @inlinable static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    @inlinable static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }

    /// Latitude/longitude (degrees) to Cartesian on a sphere of `radius` (default unit sphere).
    public static func cartesian(_ c: GeoCoordinate, radius: Double = 1) -> Cartesian3 {
        let lat = radians(c.latitude)
        let lon = radians(c.longitude)
        return Cartesian3(
            x: radius * cos(lat) * cos(lon),
            y: radius * cos(lat) * sin(lon),
            z: radius * sin(lat)
        )
    }

    /// Inverse of `cartesian` (radius is ignored).
    public static func coordinate(_ p: Cartesian3) -> GeoCoordinate {
        let r = p.length
        guard r > 0 else { return GeoCoordinate(latitude: 0, longitude: 0) }
        return GeoCoordinate(latitude: degrees(asin(max(-1, min(1, p.z / r)))), longitude: degrees(atan2(p.y, p.x)))
    }

    /// Central angle between two coordinates in radians (haversine; stable for small distances).
    public static func centralAngle(_ a: GeoCoordinate, _ b: GeoCoordinate) -> Double {
        let dLat = radians(b.latitude - a.latitude)
        let dLon = radians(b.longitude - a.longitude)
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(radians(a.latitude)) * cos(radians(b.latitude)) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * atan2(h.squareRoot(), (1 - h).squareRoot())
    }

    /// Great-circle distance in metres.
    public static func distanceMeters(_ a: GeoCoordinate, _ b: GeoCoordinate) -> Double {
        centralAngle(a, b) * earthRadiusMeters
    }

    /// Point at `fraction` (0...1) along the great circle from `a` to `b` (spherical interpolation).
    public static func interpolate(_ a: GeoCoordinate, _ b: GeoCoordinate, fraction: Double) -> GeoCoordinate {
        let t = max(0, min(1, fraction))
        let omega = centralAngle(a, b)
        if omega < 1e-12 { return a }
        let pa = cartesian(a)
        let pb = cartesian(b)
        let s = sin(omega)
        let wa = sin((1 - t) * omega) / s
        let wb = sin(t * omega) / s
        return coordinate(Cartesian3(x: wa * pa.x + wb * pb.x, y: wa * pa.y + wb * pb.y, z: wa * pa.z + wb * pb.z))
    }

    /// `count` evenly spaced points (including both endpoints) along the great-circle arc.
    public static func sampleArc(from a: GeoCoordinate, to b: GeoCoordinate, count: Int) -> [GeoCoordinate] {
        guard count >= 2 else { return count == 1 ? [a] : [] }
        return (0..<count).map { interpolate(a, b, fraction: Double($0) / Double(count - 1)) }
    }

    /// Height (fraction of radius) of a raised arc at `fraction`: a sine bump peaking mid-way,
    /// scaled with arc length so short hops stay low and intercontinental arcs lift off the globe.
    public static func arcAltitude(fraction: Double, centralAngle: Double, maxLift: Double = 0.25) -> Double {
        let t = max(0, min(1, fraction))
        let lift = maxLift * min(1, centralAngle / .pi)
        return lift * sin(.pi * t)
    }
}
