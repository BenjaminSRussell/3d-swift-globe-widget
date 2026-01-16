import SceneKit
import Foundation

/// Stage 5: Intelligent camera positioning system
/// Calculates optimal framing for sets of nodes and handles smart focus strategies
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class AutoFitCameraSystem {
    
    private let cameraNode: SCNNode
    private let scene: SCNScene
    
    // Cache for performance optimization
    private var boundsCache: [String: (SCNVector3, Float)] = [:]
    private var lastUpdate: TimeInterval = 0
    
    public init(cameraNode: SCNNode, scene: SCNScene) {
        self.cameraNode = cameraNode
        self.scene = scene
    }
    
    // MARK: - Auto-Fit Logic
    
    /// Fits camera to view specified nodes
    public func fitToNodes(
        _ nodeIds: [String],
        mode: ViewMode = .globe3D,
        completion: (() -> Void)? = nil
    ) {
        guard !nodeIds.isEmpty else { return }
        
        // 1. Calculate bounding sphere/box for nodes
        let (center, radius) = calculateBoundingSphere(for: nodeIds)
        
        // 2. Determine optimal distance based on FOV and radius
        let distance = calculateOptimalDistance(radius: radius, fov: cameraNode.camera?.fieldOfView ?? 60.0)
        
        // 3. Calculate target position
        let targetPosition = calculateTargetPosition(center: center, distance: distance, mode: mode)
        
        // 4. Animate
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.5
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        SCNTransaction.completionBlock = {
            completion?()
        }
        
        cameraNode.position = targetPosition
        cameraNode.look(at: center)
        
        SCNTransaction.commit()
    }
    
    // MARK: - Smart Focus Logic
    
    /// Focuses camera using weighted strategy
    public func smartFocus(
        _ nodeIds: [String],
        strategy: FocusStrategy,
        completion: (() -> Void)? = nil
    ) {
        // Simple implementation for now - calculates weighted center
        // Future expansion: Use network topology weights
        
        let (center, _) = calculateBoundingSphere(for: nodeIds)
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
        SCNTransaction.completionBlock = completion
        
        // Look at the weighted center but keep distance relative
        cameraNode.look(at: center)
        
        SCNTransaction.commit()
    }
    
    // MARK: - System Methods
    
    public func update(deltaTime: TimeInterval) {
        // Periodic cleanup/re-calc if needed
        lastUpdate += deltaTime
        if lastUpdate > 5.0 {
            // cleanup cache periodically
            lastUpdate = 0
        }
    }
    
    public func invalidateCache() {
        boundsCache.removeAll()
    }
    
    // MARK: - Private Calculations
    
    private func calculateBoundingSphere(for nodeIds: [String]) -> (center: SCNVector3, radius: Float) {
        // Collect positions
        // Note: In a real implementation we would fetch actual node positions from NetworkService
        // Here we simulate fetching from the scene or service
        
        // Placeholder positions (fetching actual positions would require access to NetworkService)
        // For this implementation, we assume nodeIds correspond to nodes in the scene
        var positions: [SCNVector3] = []
        
        for id in nodeIds {
            // Try to find node in scene
            if let node = scene.rootNode.childNode(withName: id, recursively: true) {
                positions.append(node.position)
            }
        }
        
        guard !positions.isEmpty else { return (SCNVector3Zero, 5.0) }
        
        // Calculate center
        let sum = positions.reduce(SCNVector3Zero) { SCNVector3($0.x + $1.x, $0.y + $1.y, $0.z + $1.z) }
        let center = SCNVector3(sum.x / Float(positions.count), sum.y / Float(positions.count), sum.z / Float(positions.count))
        
        // Calculate radius
        let maxDist = positions.map { pos -> Float in
            let dx = pos.x - center.x
            let dy = pos.y - center.y
            let dz = pos.z - center.z
            return sqrt(dx*dx + dy*dy + dz*dz)
        }.max() ?? 1.0
        
        return (center, maxDist)
    }
    
    private func calculateOptimalDistance(radius: Float, fov: CGFloat) -> Float {
        // Distance = Radius / sin(FOV/2)
        // Add minimal padding (1.2x)
        let fovRad = Float(fov) * .pi / 180.0
        return (radius * 1.2) / sin(fovRad / 2.0)
    }
    
    private func calculateTargetPosition(center: SCNVector3, distance: Float, mode: ViewMode) -> SCNVector3 {
        switch mode {
        case .globe3D:
            // Point from center relative to origin
            let direction = center.normalized()
            // If center is near zero (internal), just pull back on Z
            if direction.length() < 0.1 {
                return SCNVector3(0, 0, distance + 2.0)
            }
            return SCNVector3(center.x + direction.x * distance,
                              center.y + direction.y * distance,
                              center.z + direction.z * distance)
            
        case .globe2D, .hybrid:
            // Fixed Z-offset for 2D
            return SCNVector3(center.x, center.y, max(distance, 5.0))
        }
    }
}

private extension SCNVector3 {
    func length() -> Float {
        return sqrt(x*x + y*y + z*z)
    }
    
    func normalized() -> SCNVector3 {
        let len = length()
        return len > 0 ? SCNVector3(x/len, y/len, z/len) : SCNVector3Zero
    }
}
