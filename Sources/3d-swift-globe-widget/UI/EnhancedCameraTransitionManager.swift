import SceneKit
import Foundation

/// Enhanced camera transition manager with Stage 5 auto-fitting capabilities
/// Integrates advanced auto-fitting algorithms with existing transition system
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class CameraTransitionManager {
    
    private let cameraNode: SCNNode
    private var currentTransition: CameraTransition?
    
    // Stage 5: Auto-fitting camera system
    private var autoFitSystem: AutoFitCameraSystem?
    
    public init(cameraNode: SCNNode, scene: SCNScene? = nil) {
        self.cameraNode = cameraNode
        
        // Initialize auto-fitting system if scene is provided
        if let scene = scene {
            self.autoFitSystem = AutoFitCameraSystem(cameraNode: cameraNode, scene: scene)
        }
    }
    
    // MARK: - Stage 5 Enhanced Methods
    
    /// Auto-fits camera to display specified nodes with intelligent framing
    /// - Parameters:
    ///   - nodeIds: Array of node identifiers to fit in view
    ///   - mode: Current view mode (3D, 2D, or hybrid)
    ///   - completion: Optional completion handler
    public func autoFitToNodes(
        _ nodeIds: [String],
        mode: ViewMode = .globe3D,
        completion: (() -> Void)? = nil
    ) {
        autoFitSystem?.fitToNodes(nodeIds, mode: mode, completion: completion)
    }
    
    /// Smart focus using weighted algorithms
    /// - Parameters:
    ///   - nodeIds: Nodes to focus on
    ///   - strategy: Focus strategy (connection density, critical path, etc.)
    ///   - completion: Optional completion handler
    public func smartFocus(
        _ nodeIds: [String],
        strategy: FocusStrategy = .default,
        completion: (() -> Void)? = nil
    ) {
        autoFitSystem?.smartFocus(nodeIds, strategy: strategy, completion: completion)
    }
    
    /// Updates camera system for performance optimization
    /// - Parameter deltaTime: Time since last frame
    public func update(deltaTime: TimeInterval) {
        autoFitSystem?.update(deltaTime: deltaTime)
    }
    
    /// Invalidates cached bounds data
    public func invalidateCache() {
        autoFitSystem?.invalidateCache()
    }
    
    // MARK: - Existing Advanced Camera Transitions
    
    /// Animates camera to focus on a set of coordinates with easing
    public func focusOnPoints(_ points: [(Double, Double)], duration: TimeInterval = 1.0, completion: (() -> Void)? = nil) {
        guard !points.isEmpty else { return }
        
        // Calculate optimal camera position for viewing points
        let (centerPos, optimalDistance) = calculateOptimalCameraPosition(for: points)
        
        // Create smooth transition
        let transition = CameraTransition(
            type: .focus,
            startPosition: cameraNode.position,
            endPosition: centerPos,
            duration: duration,
            completion: completion
        )
        
        executeTransition(transition)
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

public enum ViewMode {
    case globe3D
    case globe2D
    case hybrid
}

public enum FocusStrategy {
    case `default`
    case connectionDensity
    case criticalPath
    case weightedAverage
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
