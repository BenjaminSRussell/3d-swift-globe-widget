import SceneKit
import Foundation

/// GPU-accelerated particle system for failure effects
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class ParticleSystem {
    
    private let scene: SCNScene
    private var systems: [SCNParticleSystem] = []
    
    public init(scene: SCNScene) {
        self.scene = scene
    }
    
    /// Emits a burst of particles at a specific location
    public func emitBurst(at position: SCNVector3, color: UniversalColor = .cyan) {
        let system = SCNParticleSystem()
        system.birthRate = 2000 // Increased density
        system.particleLifeSpan = 0.8
        system.particleSize = 0.015
        system.particleColor = color
        system.isLightingEnabled = true
        system.emissionDuration = 0.1
        system.loops = false
        
        // High-fidelity standard properties
        system.isLightingEnabled = true
        system.emissionDuration = 0.1
        system.loops = false
        system.particleColorVariation = SCNVector4(0.1, 0.1, 0.1, 0)
        system.acceleration = SCNVector3(0, -1, 0) // Gravity
        
        let emitterNode = SCNNode()
        emitterNode.position = position
        emitterNode.addParticleSystem(system)
        scene.rootNode.addChildNode(emitterNode)
        
        // Auto-cleanup with slightly longer duration for fade-out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            emitterNode.removeFromParentNode()
        }
    }
}
