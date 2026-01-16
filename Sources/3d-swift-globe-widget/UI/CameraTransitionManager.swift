import SceneKit
import Foundation

/// Manages camera transitions and auto-fitting logic
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class CameraTransitionManager {
    
    private let cameraNode: SCNNode
    
    public init(cameraNode: SCNNode) {
        self.cameraNode = cameraNode
    }
    
    /// Animates the camera to focus on a set of coordinates
    public func focusOnPoints(_ points: [(Double, Double)], duration: TimeInterval = 1.0) {
        guard !points.isEmpty else { return }
        
        // Calculate center of points (simple average for now)
        let midLat = points.map { $0.0 }.reduce(0, +) / Double(points.count)
        let midLon = points.map { $0.1 }.reduce(0, +) / Double(points.count)
        
        let targetPos = GeospatialMath.latLonToCartesian(lat: midLat, lon: midLon, radius: 2.5)
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        cameraNode.position = targetPos
        cameraNode.look(at: SCNVector3Zero) // Look at globe center
        SCNTransaction.commit()
    }
    
    /// Zooms out to show the whole globe
    public func resetView(duration: TimeInterval = 1.0) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        cameraNode.position = SCNVector3(0, 0, 3)
        cameraNode.look(at: SCNVector3Zero)
        SCNTransaction.commit()
    }
}
