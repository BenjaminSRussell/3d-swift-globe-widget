import Foundation
import SceneKit

/// Utilities for interpolating between spherical and planar representations
@available(iOS 15.0, macOS 12.0, *)
public struct MorphingMath {
    
    /// Interpolates between a spherical and planar position
    /// - Parameters:
    ///   - lat: Latitude
    ///   - lon: Longitude
    ///   - mix: Interpolation factor (0 = Sphere, 1 = Plane)
    /// - Returns: Interpolated SCNVector3
    public static func interpolatedPosition(lat: Double, lon: Double, mix: Float) -> SCNVector3 {
        let spherePos = GeospatialMath.latLonToCartesian(lat: lat, lon: lon)
        let planePos = GeospatialMath.latLonToPlanar(lat: lat, lon: lon)
        
        return SCNVector3(
            mixFloat(Float(spherePos.x), Float(planePos.x), mix),
            mixFloat(Float(spherePos.y), Float(planePos.y), mix),
            mixFloat(Float(spherePos.z), Float(planePos.z), mix)
        )
    }
    
    private static func mixFloat(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + (b - a) * t
    }
}
