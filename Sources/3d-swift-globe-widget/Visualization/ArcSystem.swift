import SceneKit
import Foundation

/// Handles the rendering of arcs between geospatial points
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class ArcSystem {
    
    private let scene: SCNScene
    private var arcNodes: [String: SCNNode] = [:]
    
    public init(scene: SCNScene) {
        self.scene = scene
    }
    
    /// Creates a 3D arc between two coordinates
    public func createArc(id: String, from: (Double, Double), to: (Double, Double), height: Double = 0.2) {
        let start = GeospatialMath.latLonToCartesian(lat: from.0, lon: from.1)
        let end = GeospatialMath.latLonToCartesian(lat: to.0, lon: to.1)
        
        // Calculate mid point with altitude for 3D curvature
        let distance = GeospatialMath.haversineDistance(lat1: from.0, lon1: from.1, lat2: to.0, lon2: to.1)
        let actualHeight = height * distance * 2.0 // Adjust height relative to distance
        
        // Create arc geometry using a Bezier curve
        let arcNode = createBezierArcNode(start: start, end: end, height: actualHeight)
        arcNode.name = id
        scene.rootNode.addChildNode(arcNode)
        arcNodes[id] = arcNode
        
        // Add "data flow" animation
        addAnimation(to: arcNode)
    }
    
    private func createBezierArcNode(start: SCNVector3, end: SCNVector3, height: Double) -> SCNNode {
        let mid = SCNVector3(
            CGFloat((Float(start.x) + Float(end.x)) / 2.0),
            CGFloat((Float(start.y) + Float(end.y)) / 2.0 + Float(height)),
            CGFloat((Float(start.z) + Float(end.z)) / 2.0)
        )
        
        // High-fidelity arc: Thicker and more glowy
        let tube = SCNCylinder(radius: 0.005, height: 1.0)
        tube.firstMaterial?.diffuse.contents = UniversalColor.cyan
        tube.firstMaterial?.emission.contents = UniversalColor.cyan
        tube.firstMaterial?.lightingModel = .constant
        
        let node = SCNNode(geometry: tube)
        node.position = mid
        node.look(at: end, up: scene.rootNode.worldUp, localFront: SCNVector3(0, 1, 0))
        
        return node
    }
    
    private func addAnimation(to node: SCNNode) {
        let fadeOut = SCNAction.fadeOpacity(to: 0.3, duration: 1.0)
        let fadeIn = SCNAction.fadeOpacity(to: 1.0, duration: 1.0)
        let sequence = SCNAction.sequence([fadeOut, fadeIn])
        node.runAction(SCNAction.repeatForever(sequence))
    }
    
    public func clearArcs() {
        for node in arcNodes.values {
            node.removeFromParentNode()
        }
        arcNodes.removeAll()
    }
}
