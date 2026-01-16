import Foundation
import SceneKit

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
@available(iOS 15.0, macOS 12.0, *)
public struct GeospatialMath {
    
    public static let earthRadius: Double = 1.0 // Normalized radius for the globe
    
    /// Converts Latitude and Longitude to 3D Cartesian coordinates
    /// - Parameters:
    ///   - lat: Latitude in degrees
    ///   - lon: Longitude in degrees
    ///   - radius: Radius of the sphere
    /// - Returns: SCNVector3 position
    public static func latLonToCartesian(lat: Double, lon: Double, radius: Double = earthRadius) -> SCNVector3 {
        let phi = (90 - lat) * .pi / 180
        let theta = (lon + 180) * .pi / 180
        
        let x = -(radius * sin(phi) * cos(theta))
        let z = (radius * sin(phi) * sin(theta))
        let y = (radius * cos(phi))
        
        return SCNVector3(x, y, z)
    }
    
    /// Converts Latitude and Longitude to 2D Planar coordinates (Equirectangular)
    /// - Parameters:
    ///   - lat: Latitude in degrees
    ///   - lon: Longitude in degrees
    ///   - scale: Scale factor for the plane
    /// - Returns: SCNVector3 position on Z=0 plane
    public static func latLonToPlanar(lat: Double, lon: Double, scale: Double = earthRadius) -> SCNVector3 {
        let x = (lon / 180.0) * .pi * scale
        let y = (lat / 90.0) * (.pi / 2.0) * scale
        return SCNVector3(x, y, 0)
    }
    
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
}
