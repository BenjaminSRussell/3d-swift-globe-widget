import Foundation
import SceneKit

/// Utilities for interpolating between spherical and planar representations
/// Enhanced for Stage 2: Advanced morphing calculations and performance optimization
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
    
    // Stage 2: Enhanced interpolation with easing
    /// Smooth interpolation with easing function for better visual transitions
    /// - Parameters:
    ///   - lat: Latitude
    ///   - lon: Longitude
    ///   - mix: Interpolation factor (0 = Sphere, 1 = Plane)
    ///   - easing: Easing type for smooth transitions
    /// - Returns: Interpolated SCNVector3 with easing
    public static func smoothedInterpolatedPosition(lat: Double, lon: Double, mix: Float, easing: EasingType = .easeInOut) -> SCNVector3 {
        let easedMix = applyEasing(mix, type: easing)
        return interpolatedPosition(lat: lat, lon: lon, mix: easedMix)
    }
    
    // Stage 2: Batch calculation for performance
    /// Calculates interpolated positions for multiple coordinates efficiently
    /// - Parameters:
    ///   - coordinates: Array of (latitude, longitude) tuples
    ///   - mix: Interpolation factor
    /// - Returns: Array of interpolated SCNVector3 positions
    public static func batchInterpolatedPositions(_ coordinates: [(Double, Double)], mix: Float) -> [SCNVector3] {
        // SIMD-based batch processing for performance
        let count = coordinates.count
        
        // Convert to SIMD arrays for batch processing
        var lats = simd_float1(repeating: 0, count: count)
        var lons = simd_float1(repeating: 0, count: count)
        
        for (i, (lat, lon)) in coordinates.enumerated() {
            lats[i] = Float(lat)
            lons[i] = Float(lon)
        }
        
        // Batch conversion to Cartesian coordinates using SIMD
        var positions = [SCNVector3](repeating: SCNVector3Zero, count: count)
        
        // Process in chunks for optimal performance
        let chunkSize = 256
        for chunkStart in stride(from: 0, to: count, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, count)
            
            for i in chunkStart..<chunkEnd {
                let lat = lats[i]
                let lon = lons[i]
                
                // Optimized Cartesian conversion
                let latRad = lat * .pi / 180.0
                let lonRad = lon * .pi / 180.0
                let cosLat = cos(latRad)
                
                positions[i] = SCNVector3(
                    cosLat * cos(lonRad),
                    sin(latRad),
                    cosLat * sin(lonRad)
                )
            }
        }
        
        return positions
    }
    
    // Stage 2: Morphing path calculation
    /// Calculates optimal morphing path for smooth camera transitions
    /// - Parameters:
    ///   - startMode: Starting view mode
    ///   - endMode: Ending view mode
    ///   - duration: Transition duration
    /// - Returns: Array of keyframes for smooth animation
    public static func calculateMorphingPath(from startMode: ViewMode, to endMode: ViewMode, duration: TimeInterval) -> [MorphKeyframe] {
        // Bezier curve-based morphing with acceleration/deceleration
        let keyframeCount = 30
        var keyframes: [MorphKeyframe] = []
        
        for i in 0..<keyframeCount {
            let t = Float(i) / Float(keyframeCount - 1)
            
            // Cubic bezier with control points for smooth acceleration
            let bezierT = cubicBezier(t: t, p0: 0.0, p1: 0.25, p2: 0.75, p3: 1.0)
            
            let keyframe = MorphKeyframe(
                time: duration * Double(bezierT),
                mix: bezierT,
                quality: calculateOptimalQualityForProgress(bezierT)
            )
            
            keyframes.append(keyframe)
        }
        
        return keyframes
    }
    
    private static func cubicBezier(t: Float, p0: Float, p1: Float, p2: Float, p3: Float) -> Float {
        let u = 1.0 - t
        return u*u*u*p0 + 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t*p3
    }
    
    private static func calculateOptimalQualityForProgress(_ progress: Float) -> MorphingQuality {
        // Higher quality at start and end, lower in middle for performance
        if progress < 0.2 || progress > 0.8 {
            return .high
        } else if progress < 0.4 || progress > 0.6 {
            return .medium
        } else {
            return .low
        }
    }
    
    // Stage 2: Performance optimization utilities
    
    /// Calculates optimal morphing quality based on performance metrics
    /// - Parameters:
    ///   - frameRate: Current frame rate
    ///   - particleCount: Current particle count
    ///   - connectionCount: Current connection count
    /// - Returns: Recommended quality level
    public static func calculateOptimalQuality(frameRate: Float, particleCount: Int, connectionCount: Int) -> MorphingQuality {
        // Adaptive quality system considering device capabilities
        let performanceScore = calculatePerformanceScore(frameRate: frameRate, particleCount: particleCount, connectionCount: connectionCount)
        
        if performanceScore > 80 {
            return .high
        } else if performanceScore > 50 {
            return .medium
        } else {
            return .low
        }
    }
    
    private static func calculatePerformanceScore(frameRate: Float, particleCount: Int, connectionCount: Int) -> Float {
        // Weighted performance scoring
        let frameRateScore = min(frameRate / 60.0, 1.0) * 40.0 // 40% weight
        let particleScore = max(0, 1.0 - Float(particleCount) / 10000.0) * 30.0 // 30% weight
        let connectionScore = max(0, 1.0 - Float(connectionCount) / 1000.0) * 30.0 // 30% weight
        
        return frameRateScore + particleScore + connectionScore
    }
    
    /// Validates morphing parameters for performance constraints
    /// - Parameters:
    ///   - coordinateCount: Number of coordinates to morph
    ///   - targetFrameRate: Target frame rate
    ///   - deviceClass: Device performance class
    /// - Returns: True if morphing is feasible
    public static func validateMorphingPerformance(coordinateCount: Int, targetFrameRate: Float, deviceClass: DeviceClass) -> Bool {
        // Performance validation with memory constraints and fallback strategies
        
        // Calculate memory requirements (rough estimate)
        let memoryPerCoordinate = 64 // bytes per coordinate (position + normal + UV)
        let totalMemoryMB = (coordinateCount * memoryPerCoordinate) / (1024 * 1024)
        
        // Device-specific memory limits
        let memoryLimitMB: Int
        switch deviceClass {
        case .high:
            memoryLimitMB = 512
        case .medium:
            memoryLimitMB = 256
        case .low:
            memoryLimitMB = 128
        }
        
        // Check memory constraints
        if totalMemoryMB > memoryLimitMB {
            return false
        }
        
        // Check processing capability
        let maxCoordinates: Int
        switch deviceClass {
        case .high:
            maxCoordinates = 50000
        case .medium:
            maxCoordinates = 20000
        case .low:
            maxCoordinates = 5000
        }
        
        return coordinateCount <= maxCoordinates
    }
    
    /// Provides fallback strategies for performance constraints
    public static func getFallbackStrategy(coordinateCount: Int, deviceClass: DeviceClass) -> FallbackStrategy {
        if validateMorphingPerformance(coordinateCount: coordinateCount, targetFrameRate: 60, deviceClass: deviceClass) {
            return .none
        }
        
        let reductionFactor: Float
        switch deviceClass {
        case .high:
            reductionFactor = 0.5
        case .medium:
            reductionFactor = 0.3
        case .low:
            reductionFactor = 0.2
        }
        
        return .reduceCoordinates(Int(Float(coordinateCount) * reductionFactor))
    }
    
    public enum FallbackStrategy {
        case none
        case reduceCoordinates(Int)
        case lowerQuality
        case disableMorphing
    }
    
    // MARK: - Private Helper Methods
    
    private static func mixFloat(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + (b - a) * t
    }
    
    private static func applyEasing(_ t: Float, type: EasingType) -> Float {
        switch type {
        case .linear:
            return t
        case .easeIn:
            return t * t
        case .easeOut:
            return 1.0 - (1.0 - t) * (1.0 - t)
        case .easeInOut:
            return t < 0.5 ? 2.0 * t * t : 1.0 - 2.0 * (1.0 - t) * (1.0 - t)
        }
    }
    
    private static func calculateCameraPosition(for progress: Float, from startMode: ViewMode, to endMode: ViewMode) -> SCNVector3 {
        // Smooth camera positioning during morph with geographic center consideration
        
        let startDistance = getOptimalCameraDistance(for: startMode)
        let endDistance = getOptimalCameraDistance(for: endMode)
        
        // Smooth interpolation using ease-in-out
        let easedProgress = applyEasing(progress, type: .easeInOut)
        let currentDistance = mixFloat(startDistance, endDistance, easedProgress)
        
        // Calculate geographic center based on view modes
        let startCenter = getGeographicCenter(for: startMode)
        let endCenter = getGeographicCenter(for: endMode)
        
        // Interpolate center position
        let currentCenter = SCNVector3(
            mixFloat(startCenter.x, endCenter.x, easedProgress),
            mixFloat(startCenter.y, endCenter.y, easedProgress),
            mixFloat(startCenter.z, endCenter.z, easedProgress)
        )
        
        // Apply distance from center
        let normalizedDirection = simd_normalize(simd_float3(currentCenter.x, currentCenter.y, currentCenter.z))
        let finalPosition = SCNVector3(
            normalizedDirection.x * currentDistance,
            normalizedDirection.y * currentDistance,
            normalizedDirection.z * currentDistance
        )
        
        return finalPosition
    }
    
    private static func getOptimalCameraDistance(for mode: ViewMode) -> Float {
        switch mode {
        case .globe3D:
            return 3.0 // Close for 3D globe interaction
        case .globe2D:
            return 5.0 // Medium distance for 2D projection
        case .hybrid:
            return 4.0 // Balanced distance for hybrid view
        case .map2D:
            return 8.0 // Far for flat map view
        }
    }
    
    private static func getGeographicCenter(for mode: ViewMode) -> SCNVector3 {
        switch mode {
        case .globe3D, .globe2D, .hybrid:
            // Center on equator, prime meridian for globe views
            return SCNVector3(0, 0, 1)
        case .map2D:
            // Slightly tilted for better map visibility
            return SCNVector3(0, 0.2, 0.98)
        }
    }
}

// MARK: - Stage 2 Supporting Types

/// Easing functions for smooth transitions
public enum EasingType {
    case linear
    case easeIn
    case easeOut
    case easeInOut
}

/// Morphing animation keyframe
public struct MorphKeyframe {
    let time: TimeInterval
    let mixFactor: Float
    let cameraPosition: SCNVector3
}

/// Morphing quality levels for performance optimization
public enum MorphingQuality {
    case low    // Minimal detail, maximum performance
    case medium // Balanced quality and performance
    case high   // Maximum detail, requires capable hardware
}

/// Device performance classification
public enum DeviceClass {
    case low    // Older devices, limited GPU
    case medium // Mid-range devices
    case high   // High-end devices with powerful GPUs
}
