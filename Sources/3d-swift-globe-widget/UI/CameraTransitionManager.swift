import SceneKit
import Foundation

/// Manages camera transitions and auto-fitting logic
/// Enhanced for Phase 2: Advanced Globe Morphing and Camera Systems
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class CameraTransitionManager {
    
    private let cameraNode: SCNNode
    private var currentTransition: CameraTransition?
    
    public init(cameraNode: SCNNode) {
        self.cameraNode = cameraNode
    }
    
    // MARK: - Advanced Camera Transitions
    
    /// Calculates optimal camera position for viewing multiple points
    /// Enhanced for Stage 2: Advanced auto-fitting algorithms
    /// - Parameter points: Array of (latitude, longitude) tuples
    /// - Returns: Tuple containing (center position, optimal distance, bounding sphere)
    public func calculateOptimalCameraPosition(for points: [(Double, Double)]) -> (SCNVector3, Float, BoundingSphere) {
        guard !points.isEmpty else { return (SCNVector3(0, 0, 3), 3.0, BoundingSphere(center: SCNVector3Zero, radius: 1.0)) }
        
        // Convert all points to 3D cartesian coordinates
        let positions3D = points.map { GeospatialMath.latLonToCartesian(lat: $0.0, lon: $0.1, radius: 1.0) }
        
        // Calculate bounding sphere that encompasses all points
        let boundingSphere = calculateBoundingSphere(for: positions3D)
        
        // Calculate optimal camera distance based on field of view
        let optimalDistance = calculateOptimalDistance(for: boundingSphere.radius)
        
        // Position camera at optimal distance from sphere center
        let cameraPosition = boundingSphere.center.normalized() * optimalDistance
        
        return (cameraPosition, optimalDistance, boundingSphere)
    }
    
    /// Focuses camera on specified points with auto-fitting
    /// Enhanced for Stage 2: Intelligent framing with smooth transitions
    /// - Parameters:
    ///   - points: Array of (latitude, longitude) tuples
    ///   - duration: Transition duration
    ///   - padding: Additional padding around bounding box (0.0-1.0)
    ///   - completion: Completion handler
    public func focusOnPoints(_ points: [(Double, Double)], duration: TimeInterval = 1.0, padding: Float = 0.1, completion: (() -> Void)? = nil) {
        guard !points.isEmpty else { return }
        
        let (centerPos, optimalDistance, boundingSphere) = calculateOptimalCameraPosition(for: points)
        
        // Apply padding to ensure all points are visible
        let paddedDistance = optimalDistance * (1.0 + padding)
        let finalPosition = centerPos.normalized() * paddedDistance
        
        // Create smooth transition with enhanced easing
        let transition = CameraTransition(
            type: .focus,
            startPosition: cameraNode.position,
            endPosition: finalPosition,
            duration: duration,
            completion: completion
        )
        
        executeTransition(transition)
        
        // Point camera towards bounding sphere center
        cameraNode.look(at: boundingSphere.center)
    }
    
    /// Smooth morphing transition between 3D and 2D views
    public func morphToViewMode(_ mode: ViewMode, duration: TimeInterval = 2.0, completion: (() -> Void)? = nil) {
        let targetPosition = calculatePositionForViewMode(mode)
        let targetRotation = calculateRotationForViewMode(mode)
        
        let transition = CameraTransition(
            type: .morph,
            startPosition: cameraNode.position,
            endPosition: targetPosition,
            startRotation: cameraNode.rotation,
            endRotation: targetRotation,
            duration: duration,
            completion: completion
        )
        
        executeTransition(transition)
    }
    
    /// Orbital camera movement around the globe
    public func orbitAroundGlobe(duration: TimeInterval = 10.0, completion: (() -> Void)? = nil) {
        let orbitAction = SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: duration)
        )
        
        cameraNode.runAction(orbitAction)
        
        // Store transition for potential cancellation
        currentTransition = CameraTransition(
            type: .orbit,
            action: orbitAction,
            completion: completion
        )
    }
    
    /// Zooms to specific distance with smooth easing
    public func zoomToDistance(_ distance: Float, duration: TimeInterval = 1.0, completion: (() -> Void)? = nil) {
        let currentDirection = SCNVector3(
            cameraNode.position.x,
            cameraNode.position.y,
            cameraNode.position.z
        ).normalized()
        
        let targetPosition = SCNVector3(
            currentDirection.x * distance,
            currentDirection.y * distance,
            currentDirection.z * distance
        )
        
        let transition = CameraTransition(
            type: .zoom,
            startPosition: cameraNode.position,
            endPosition: targetPosition,
            duration: duration,
            completion: completion
        )
        
        executeTransition(transition)
    }
    
    /// Resets camera to default globe view with enhanced animation
    public func resetView(duration: TimeInterval = 1.5, completion: (() -> Void)? = nil) {
        let transition = CameraTransition(
            type: .reset,
            startPosition: cameraNode.position,
            endPosition: SCNVector3(0, 0, 3),
            startRotation: cameraNode.rotation,
            endRotation: SCNVector4Zero,
            duration: duration,
            completion: completion
        )
        
        executeTransition(transition)
    }
    
    // MARK: - Private Helper Methods
    
    private func calculateOptimalCameraPosition(for points: [(Double, Double)]) -> (SCNVector3, Float) {
        guard !points.isEmpty else { return (SCNVector3(0, 0, 3), 3.0) }
        
        // Calculate center point
        let midLat = points.map { $0.0 }.reduce(0, +) / Double(points.count)
        let midLon = points.map { $0.1 }.reduce(0, +) / Double(points.count)
        
        // Calculate bounding box for optimal distance
        let lats = points.map { $0.0 }
        let lons = points.map { $0.1 }
        let latRange = (lats.max() ?? 0) - (lats.min() ?? 0)
        let lonRange = (lons.max() ?? 0) - (lons.min() ?? 0)
        
        // Calculate optimal viewing distance based on spread
        let maxSpread = max(latRange, lonRange)
        let optimalDistance = Double(2.0 + maxSpread * 2.0)
        
        let centerPos = GeospatialMath.latLonToCartesian(lat: midLat, lon: midLon, radius: optimalDistance)
        
        return (centerPos, optimalDistance)
    }
    
    private func calculatePositionForViewMode(_ mode: ViewMode) -> SCNVector3 {
        switch mode {
        case .globe3D:
            return SCNVector3(0, 0, 3)
        case .globe2D:
            return SCNVector3(0, 0, 5)
        case .hybrid:
            return SCNVector3(0, 0, 4)
        }
    }
    
    private func calculateRotationForViewMode(_ mode: ViewMode) -> SCNVector4 {
        switch mode {
        case .globe3D:
            return SCNVector4Zero
        case .globe2D:
            return SCNVector4(x: .pi/4, y: 0, z: 0, w: 1)
        case .hybrid:
            return SCNVector4(x: .pi/8, y: 0, z: 0, w: 1)
        }
    }
    
    private func executeTransition(_ transition: CameraTransition) {
        // Cancel any existing transition
        cancelCurrentTransition()
        
        currentTransition = transition
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = transition.duration
        // Enhanced easing function for smoother transitions
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        SCNTransaction.completionBlock = { _ in
            transition.completion?()
            self.currentTransition = nil
        }
        
        // Apply position and rotation changes
        cameraNode.position = transition.endPosition
        if let endRotation = transition.endRotation {
            cameraNode.rotation = endRotation
        }
        
        // Handle special transition types
        switch transition.type {
        case .focus:
            cameraNode.look(at: SCNVector3Zero)
        case .reset:
            cameraNode.look(at: SCNVector3Zero)
        case .morph:
            // Additional morph-specific setup could go here
            break
        default:
            break
        }
        
        SCNTransaction.commit()
    }
    
    // MARK: - Stage 2 Enhanced Helper Methods
    
    /// Calculates bounding sphere for a set of 3D points
    /// - Parameter positions: Array of SCNVector3 positions
    /// - Returns: Bounding sphere containing all points
    private func calculateBoundingSphere(for positions: [SCNVector3]) -> BoundingSphere {
        guard !positions.isEmpty else { return BoundingSphere(center: SCNVector3Zero, radius: 1.0) }
        
        // Calculate centroid
        let sum = positions.reduce(SCNVector3Zero) { result, position in
            SCNVector3(result.x + position.x, result.y + position.y, result.z + position.z)
        }
        let centroid = SCNVector3(sum.x / Float(positions.count), sum.y / Float(positions.count), sum.z / Float(positions.count))
        
        // Find maximum distance from centroid
        let maxDistance = positions.map { position in
            let dx = position.x - centroid.x
            let dy = position.y - centroid.y
            let dz = position.z - centroid.z
            return sqrt(dx*dx + dy*dy + dz*dz)
        }.max() ?? 1.0
        
        return BoundingSphere(center: centroid, radius: maxDistance)
    }
    
    /// Calculates optimal camera distance based on bounding sphere radius and field of view
    /// - Parameter boundingRadius: Radius of bounding sphere
    /// - Returns: Optimal camera distance
    private func calculateOptimalDistance(for boundingRadius: Float) -> Float {
        // TODO: Consider camera field of view for accurate calculation
        // TODO: Account for aspect ratio differences
        // TODO: Add safety margin for edge cases
        
        // Simple calculation: ensure sphere fits in view with margin
        let fovRadians: Float = .pi / 3 // Assuming 60 degree FOV
        let distance = boundingRadius / sin(fovRadians / 2)
        return distance * 1.2 // 20% safety margin
    }
    
    private func cancelCurrentTransition() {
        if let transition = currentTransition {
            switch transition.type {
            case .orbit:
                cameraNode.removeAction(forKey: "orbit")
            default:
                break
            }
            currentTransition = nil
        }
    }
}

// MARK: - Supporting Types

/// Represents a bounding sphere for 3D calculations
public struct BoundingSphere {
    let center: SCNVector3
    let radius: Float
}

public enum ViewMode {
    case globe3D
    case globe2D
    case hybrid
}

private struct CameraTransition {
    let type: TransitionType
    let startPosition: SCNVector3
    let endPosition: SCNVector3
    let startRotation: SCNVector4?
    let endRotation: SCNVector4?
    let duration: TimeInterval
    let completion: (() -> Void)?
    let action: SCNAction?
    
    init(type: TransitionType, startPosition: SCNVector3, endPosition: SCNVector3, 
         startRotation: SCNVector4? = nil, endRotation: SCNVector4? = nil, 
         duration: TimeInterval, completion: (() -> Void)? = nil, action: SCNAction? = nil) {
        self.type = type
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.startRotation = startRotation
        self.endRotation = endRotation
        self.duration = duration
        self.completion = completion
        self.action = action
    }
}

private enum TransitionType {
    case focus
    case morph
    case orbit
    case zoom
    case reset
}

private extension SCNVector3 {
    func normalized() -> SCNVector3 {
        let length = sqrt(x*x + y*y + z*z)
        guard length > 0 else { return SCNVector3Zero }
        return SCNVector3(x/length, y/length, z/length)
    }
}
