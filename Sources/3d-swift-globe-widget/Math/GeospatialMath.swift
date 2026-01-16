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

/// Core mathematical foundation for geospatial calculations
/// Stage 5: Enhanced with camera system support for auto-fitting algorithms
@available(iOS 15.0, macOS 12.0, *)
public struct GeospatialMath {
    
    // Stage 5: Support for different projection systems
    public enum ProjectionType {
        case spherical
        case mercator
        case robinson
        case orthographic
        case stereographic
    }
    
    // Stage 5: Coordinate transformation utilities for camera bounds calculations
    
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
    public static func calculateOptimalCameraDistance(bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double), fov: Double = .pi/3, aspectRatio: Double = 16.0/9.0, padding: Double = 1.2) -> Double {
        // Precise camera distance calculation considering aspect ratio and padding
        
        let latCenter = (bounds.minLat + bounds.maxLat) / 2
        let lonCenter = (bounds.minLon + bounds.maxLon) / 2
        
        let latSpan = bounds.maxLat - bounds.minLat
        let lonSpan = bounds.maxLon - bounds.minLon
        
        // Convert geographic spans to 3D distances
        let latDistance = haversineDistance(lat1: bounds.minLat, lon1: lonCenter, lat2: bounds.maxLat, lon2: lonCenter)
        let lonDistance = haversineDistance(lat1: latCenter, lon1: bounds.minLon, lat2: latCenter, lon2: bounds.maxLon)
        
        // Account for aspect ratio to ensure both dimensions fit
        let horizontalFOV = fov
        let verticalFOV = 2 * atan(tan(fov / 2) / aspectRatio)
        
        // Calculate required distances for each dimension
        let distanceForLat = (latDistance * padding) / (2 * tan(verticalFOV / 2))
        let distanceForLon = (lonDistance * padding) / (2 * tan(horizontalFOV / 2))
        
        // Use the maximum distance to ensure full visibility
        let optimalDistance = max(distanceForLat, distanceForLon)
        
        // Ensure minimum distance for globe visibility
        let minDistance = earthRadius * 1.5
        
        return max(optimalDistance, minDistance)
    }
    
    /// Calculates optimal camera distance for different projection types
    public static func calculateOptimalCameraDistanceForProjection(bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double), projection: ProjectionType = .spherical, fov: Double = .pi/3, aspectRatio: Double = 16.0/9.0) -> Double {
        switch projection {
        case .spherical:
            return calculateOptimalCameraDistance(bounds: bounds, fov: fov, aspectRatio: aspectRatio)
        case .mercator:
            // For mercator, account for distortion at higher latitudes
            let latCenter = (bounds.minLat + bounds.maxLat) / 2
            let mercatorScale = 1.0 / cos(latCenter * .pi / 180.0)
            return calculateOptimalCameraDistance(bounds: bounds, fov: fov, aspectRatio: aspectRatio) * mercatorScale
        case .orthographic:
            // For orthographic, use simpler calculation
            let latSpan = bounds.maxLat - bounds.minLat
            let lonSpan = bounds.maxLon - bounds.minLon
            let maxSpan = max(latSpan, lonSpan)
            return earthRadius * maxSpan * 1.5
        }
    }
    
    public enum ProjectionType {
        case spherical
        case mercator
        case orthographic
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
    
    // MARK: - Stage 5: Great Circle Interpolation
    
    /// Interpolates points along a great circle path for smooth arc rendering
    /// - Parameters:
    ///   - startLat: Starting latitude
    ///   - startLon: Starting longitude
    ///   - endLat: Ending latitude
    ///   - endLon: Ending longitude
    ///   - segments: Number of segments to generate
    /// - Returns: Array of interpolated coordinates
    public static func greatCircleInterpolation(
        startLat: Double, startLon: Double,
        endLat: Double, endLon: Double,
        segments: Int = 20
    ) -> [(Double, Double)] {
        var points: [(Double, Double)] = []
        
        let lat1 = startLat * .pi / 180
        let lon1 = startLon * .pi / 180
        let lat2 = endLat * .pi / 180
        let lon2 = endLon * .pi / 180
        
        // Calculate great circle parameters
        let d = acos(sin(lat1) * sin(lat2) + cos(lat1) * cos(lat2) * cos(lon2 - lon1))
        
        for i in 0...segments {
            let f = Double(i) / Double(segments)
            let a = sin((1 - f) * d) / sin(d)
            let b = sin(f * d) / sin(d)
            
            let x = a * cos(lat1) * cos(lon1) + b * cos(lat2) * cos(lon2)
            let y = a * cos(lat1) * sin(lon1) + b * cos(lat2) * sin(lon2)
            let z = a * sin(lat1) + b * sin(lat2)
            
            let lat = atan2(z, sqrt(x * x + y * y)) * 180 / .pi
            let lon = atan2(y, x) * 180 / .pi
            
            points.append((lat, lon))
        }
        
        return points
    }
    
    // MARK: - Stage 5: Projection Transformations
    
    /// Transforms coordinates based on projection type
    /// - Parameters:
    ///   - lat: Latitude in degrees
    ///   - lon: Longitude in degrees
    ///   - projection: Target projection type
    /// - Returns: Transformed 3D position
    public static func projectCoordinate(
        lat: Double, lon: Double,
        projection: ProjectionType = .spherical
    ) -> SCNVector3 {
        switch projection {
        case .spherical:
            return latLonToCartesian(lat: lat, lon: lon)
        case .mercator:
            return mercatorProjection(lat: lat, lon: lon)
        case .robinson:
            return robinsonProjection(lat: lat, lon: lon)
        case .orthographic:
            return orthographicProjection(lat: lat, lon: lon)
        case .stereographic:
            return stereographicProjection(lat: lat, lon: lon)
        }
    }
    
    /// Mercator projection for 2D map views
    private static func mercatorProjection(lat: Double, lon: Double) -> SCNVector3 {
        let latRad = lat * .pi / 180
        let lonRad = lon * .pi / 180
        
        let x = lonRad
        let y = log(tan(.pi/4 + latRad/2))
        
        return SCNVector3(Float(x), Float(y), 0)
    }
    
    /// Robinson projection for world maps
    private static func robinsonProjection(lat: Double, lon: Double) -> SCNVector3 {
        let latRad = lat * .pi / 180
        let lonRad = lon * .pi / 180
        
        // Simplified Robinson projection coefficients
        let latDeg = lat
        let x = lonRad * (1.0 - 0.0001 * latDeg * latDeg)
        let y = latRad * (0.9 - 0.0002 * latDeg * latDeg)
        
        return SCNVector3(Float(x), Float(y), 0)
    }
    
    /// Orthographic projection for globe views
    private static func orthographicProjection(lat: Double, lon: Double) -> SCNVector3 {
        let latRad = lat * .pi / 180
        let lonRad = lon * .pi / 180
        
        let x = cos(latRad) * sin(lonRad)
        let y = sin(latRad)
        let z = cos(latRad) * cos(lonRad)
        
        return SCNVector3(Float(x), Float(y), Float(z))
    }
    
    /// Stereographic projection for polar views
    private static func stereographicProjection(lat: Double, lon: Double) -> SCNVector3 {
        let latRad = lat * .pi / 180
        let lonRad = lon * .pi / 180
        
        let k = 2.0 / (1.0 + sin(latRad))
        let x = k * cos(latRad) * cos(lonRad)
        let y = k * cos(latRad) * sin(lonRad)
        
        return SCNVector3(Float(x), Float(y), 0)
    }
    
    /// Calculates camera bounds for given projection and view parameters
    /// - Parameters:
    ///   - projection: Current projection type
    ///   - fov: Field of view in radians
    ///   - aspectRatio: View aspect ratio
    ///   - centerLat: Center latitude
    ///   - centerLon: Center longitude
    /// - Returns: Geographic bounds that fit in view
    public static func calculateCameraBounds(
        projection: ProjectionType,
        fov: Double = .pi/3,
        aspectRatio: Double = 16.0/9.0,
        centerLat: Double = 0,
        centerLon: Double = 0
    ) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        
        switch projection {
        case .spherical:
            // For spherical, calculate visible area based on FOV
            let latRange = fov * 180 / .pi
            let lonRange = fov * aspectRatio * 180 / .pi
            
            return (
                minLat: centerLat - latRange/2,
                maxLat: centerLat + latRange/2,
                minLon: centerLon - lonRange/2,
                maxLon: centerLon + lonRange/2
            )
        case .mercator:
            // For Mercator, account for distortion
            let latRange = fov * 180 / .pi * 0.8 // Reduced due to stretching
            let lonRange = fov * aspectRatio * 180 / .pi
            
            return (
                minLat: max(-85, centerLat - latRange/2), // Mercator limit
                maxLat: min(85, centerLat + latRange/2),
                minLon: centerLon - lonRange/2,
                maxLon: centerLon + lonRange/2
            )
        default:
            // For other projections, use simplified bounds
            let range = 90.0 // Default visible range
            return (
                minLat: centerLat - range/2,
                maxLat: centerLat + range/2,
                minLon: centerLon - range/2,
                maxLon: centerLon + range/2
            )
        }
    }
}
