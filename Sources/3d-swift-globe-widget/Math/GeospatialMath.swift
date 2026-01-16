import Foundation

#if canImport(UIKit)
import UIKit
public typealias UniversalColor = UIColor
public typealias UniversalFont = UIFont
#elseif canImport(AppKit)
import AppKit
public typealias UniversalColor = NSColor
public typealias UniversalFont = NSFont
#endif

/// Core definitions and mathematical helpers
/// Enhanced for Stage 2: Geographic projections and coordinate transformations
@available(iOS 15.0, macOS 12.0, *)
public struct GeospatialMath {
    
    public static let earthRadius: Double = 1.0 // Normalized radius for the globe
    
    /// Calculates the great circle distance between two points
    public static func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon/2) * sin(dLon/2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return earthRadius * c
    }
    
    // Stage 2: Coordinate transformation methods
    
    /// Converts latitude/longitude to 3D cartesian coordinates
    /// - Parameters:
    ///   - lat: Latitude in degrees
    ///   - lon: Longitude in degrees
    ///   - radius: Sphere radius (default: earthRadius)
    /// - Returns: 3D position as SCNVector3
    public static func latLonToCartesian(lat: Double, lon: Double, radius: Double = earthRadius) -> (x: Double, y: Double, z: Double) {
        let latRad = lat * .pi / 180
        let lonRad = lon * .pi / 180
        
        let x = radius * cos(latRad) * cos(lonRad)
        let y = radius * sin(latRad)
        let z = radius * cos(latRad) * sin(lonRad)
        
        return (x, y, z)
    }
    
    /// Converts latitude/longitude to 2D planar coordinates (equirectangular projection)
    /// - Parameters:
    ///   - lat: Latitude in degrees
    ///   - lon: Longitude in degrees
    ///   - radius: Projection radius (default: earthRadius)
    /// - Returns: 2D position as SCNVector3 (z = 0)
    public static func latLonToPlanar(lat: Double, lon: Double, radius: Double = earthRadius) -> (x: Double, y: Double, z: Double) {
        let latRad = lat * .pi / 180
        let lonRad = lon * .pi / 180
        
        let x = lonRad * radius
        let y = latRad * radius
        let z = 0.0
        
        return (x, y, z)
    }
    
    // Stage 2: Advanced projection methods
    
    /// Converts coordinates using Mercator projection
    /// - Parameters:
    ///   - lat: Latitude in degrees
    ///   - lon: Longitude in degrees
    ///   - radius: Projection radius
    /// - Returns: 2D Mercator coordinates
    public static func latLonToMercator(lat: Double, lon: Double, radius: Double = earthRadius) -> (x: Double, y: Double, z: Double) {
        let lonRad = lon * .pi / 180
        let latRad = lat * .pi / 180
        
        let x = lonRad * radius
        let y = log(tan(.pi/4 + latRad/2)) * radius
        let z = 0.0
        
        return (x, y, z)
    }
    
    /// Calculates optimal camera distance for viewing geographic region
    /// - Parameters:
    ///   - bounds: Geographic bounds (minLat, maxLat, minLon, maxLon)
    ///   - fov: Camera field of view in radians
    /// - Returns: Optimal camera distance
    public static func calculateOptimalCameraDistance(bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double), fov: Double = .pi/3) -> Double {
        // TODO: Implement precise camera distance calculation
        // TODO: Consider aspect ratio and padding
        // TODO: Add support for different projection types
        
        let latCenter = (bounds.minLat + bounds.maxLat) / 2
        let lonCenter = (bounds.minLon + bounds.maxLon) / 2
        
        let latSpan = bounds.maxLat - bounds.minLat
        let lonSpan = bounds.maxLon - bounds.minLon
        
        let maxSpan = max(latSpan, lonSpan)
        let distance = maxSpan * 2.0 / tan(fov / 2)
        
        return distance
    }
    
    // Stage 2: Geographic utilities
    
    /// Checks if a point is within geographic bounds
    /// - Parameters:
    ///   - lat: Latitude to check
    ///   - lon: Longitude to check
    ///   - bounds: Geographic bounds
    /// - Returns: True if point is within bounds
    public static func isPointInBounds(lat: Double, lon: Double, bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)) -> Bool {
        return lat >= bounds.minLat && lat <= bounds.maxLat && lon >= bounds.minLon && lon <= bounds.maxLon
    }
    
    /// Calculates geographic center of multiple points
    /// - Parameter points: Array of (latitude, longitude) tuples
    /// - Returns: Center point as (lat, lon)
    public static func calculateGeographicCenter(_ points: [(Double, Double)]) -> (lat: Double, lon: Double) {
        guard !points.isEmpty else { return (0.0, 0.0) }
        
        let avgLat = points.map { $0.0 }.reduce(0, +) / Double(points.count)
        let avgLon = points.map { $0.1 }.reduce(0, +) / Double(points.count)
        
        return (avgLat, avgLon)
    }
}
