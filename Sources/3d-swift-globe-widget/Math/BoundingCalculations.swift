import Foundation
import SceneKit

/// Bounding volume calculations for camera auto-fitting algorithms
/// Stage 5: Camera Systems - Mathematical foundation for intelligent framing
@available(iOS 15.0, macOS 12.0, *)
public struct BoundingCalculations {
    
    // MARK: - 3D Bounding Sphere
    
    /// Calculates the minimal bounding sphere for a set of 3D points
    /// Uses iterative refinement for optimal results
    /// - Parameter positions: Array of 3D positions
    /// - Returns: Bounding sphere with center and radius
    public static func calculateBoundingSphere(_ positions: [SCNVector3]) -> (center: SCNVector3, radius: Float) {
        guard !positions.isEmpty else { return (SCNVector3Zero, 0) }
        
        // Initial approximation: use centroid
        var center = SCNVector3Zero
        for pos in positions {
            center = center + pos
        }
        center = center / Float(positions.count)
        
        // Find maximum distance from center
        var radius: Float = 0
        for pos in positions {
            let distance = distance(from: center, to: pos)
            radius = max(radius, distance)
        }
        
        // Refine using iterative approach (Ritter's algorithm approximation)
        let iterations = 10
        for _ in 0..<iterations {
            var farthestPoint: SCNVector3?
            var maxDistance = radius
            
            for pos in positions {
                let distance = distance(from: center, to: pos)
                if distance > maxDistance {
                    maxDistance = distance
                    farthestPoint = pos
                }
            }
            
            if let farthest = farthestPoint {
                // Move center toward farthest point
                let direction = normalize(farthest - center)
                let adjustment = (maxDistance - radius) * 0.1
                center = center + direction * adjustment
                radius = maxDistance
            }
        }
        
        return (center, radius)
    }
    
    // MARK: - 2D Bounding Box
    
    /// Calculates bounding box for 2D planar coordinates
    /// - Parameter positions: Array of 2D positions (using SCNVector3 with z=0)
    /// - Returns: Bounding box with center and size
    public static func calculateBoundingBox2D(_ positions: [SCNVector3]) -> (center: SCNVector2, size: SCNVector2) {
        guard !positions.isEmpty else { return (SCNVector2Zero, SCNVector2Zero) }
        
        var minX: Float = .infinity
        var maxX: Float = -.infinity
        var minY: Float = .infinity
        var maxY: Float = -.infinity
        
        for pos in positions {
            minX = min(minX, pos.x)
            maxX = max(maxX, pos.x)
            minY = min(minY, pos.y)
            maxY = max(maxY, pos.y)
        }
        
        let center = SCNVector2(
            (minX + maxX) / 2,
            (minY + maxY) / 2
        )
        
        let size = SCNVector2(
            maxX - minX,
            maxY - minY
        )
        
        return (center, size)
    }
    
    // MARK: - Camera Distance Calculations
    
    /// Calculates optimal camera distance for perspective projection
    /// - Parameters:
    ///   - boundingRadius: Radius of bounding sphere to fit
    ///   - fov: Camera field of view in degrees
    ///   - aspectRatio: Camera aspect ratio (width/height)
    ///   - padding: Additional padding factor (default 1.2)
    /// - Returns: Optimal camera distance
    public static func calculateCameraDistance(
        boundingRadius: Float,
        fov: Float,
        aspectRatio: Float,
        padding: Float = 1.2
    ) -> Float {
        let fovRad = fov * .pi / 180
        
        // Distance to fit sphere vertically
        let verticalDistance = boundingRadius / sinf(fovRad / 2)
        
        // Distance to fit sphere horizontally
        let horizontalFov = 2 * atanf(tanf(fovRad / 2) * aspectRatio)
        let horizontalDistance = boundingRadius / sinf(horizontalFov / 2)
        
        // Use the larger distance with padding
        return max(verticalDistance, horizontalDistance) * padding
    }
    
    /// Calculates optimal zoom for orthographic camera
    /// - Parameters:
    ///   - boundingBox: 2D bounding box to fit
    ///   - viewportSize: Viewport dimensions
    ///   - padding: Additional padding factor (default 1.1)
    /// - Returns: Optimal zoom level
    public static func calculateOrthographicZoom(
        boundingBox: (center: SCNVector2, size: SCNVector2),
        viewportSize: CGSize,
        padding: Float = 1.1
    ) -> Float {
        let horizontalZoom = Float(viewportSize.width) / (boundingBox.size.x * padding)
        let verticalZoom = Float(viewportSize.height) / (boundingBox.size.y * padding)
        
        // Use the smaller zoom (fits both dimensions)
        return min(horizontalZoom, verticalZoom)
    }
    
    // MARK: - Helper Functions
    
    private static func distance(from a: SCNVector3, to b: SCNVector3) -> Float {
        let dx = a.x - b.x
        let dy = a.y - b.y
        let dz = a.z - b.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    
    private static func normalize(_ vector: SCNVector3) -> SCNVector3 {
        let length = sqrt(vector.x*vector.x + vector.y*vector.y + vector.z*vector.z)
        guard length > 0 else { return SCNVector3Zero }
        return SCNVector3(vector.x/length, vector.y/length, vector.z/length)
    }
}

// MARK: - SCNVector Extensions

private extension SCNVector3 {
    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
    
    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }
    
    static func * (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }
    
    static func / (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        SCNVector3(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
    }
}

public struct SCNVector2 {
    public var x: Float
    public var y: Float
    
    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
    
    public static let zero = SCNVector2(x: 0, y: 0)
    public static let SCNVector2Zero = SCNVector2.zero
}

extension SCNVector2: Equatable {
    public static func == (lhs: SCNVector2, rhs: SCNVector2) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}
