import SceneKit
import Foundation
import simd

/// Advanced particle physics system for connection failure visualization
/// Phase 3: Realistic particle effects for network failures
@available(iOS 15.0, macOS 12.0, *)
public class ConnectionFailurePhysics: ObservableObject {
    
    // MARK: - Particle Types
    public enum FailureType {
        case timeout
        case connectionLost
        case overload
        case securityBreach
        case hardwareFailure
        
        var particleColor: UniversalColor {
            switch self {
            case .timeout: return UniversalColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.9)
            case .connectionLost: return UniversalColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.9)
            case .overload: return UniversalColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.9)
            case .securityBreach: return UniversalColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 0.9)
            case .hardwareFailure: return UniversalColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.9)
            }
        }
        
        var explosionForce: Float {
            switch self {
            case .timeout: return 8.0
            case .connectionLost: return 12.0
            case .overload: return 15.0
            case .securityBreach: return 20.0
            case .hardwareFailure: return 6.0
            }
        }
        
        var particleCount: Int {
            switch self {
            case .timeout: return 50
            case .connectionLost: return 80
            case .overload: return 120
            case .securityBreach: return 150
            case .hardwareFailure: return 30
            }
        }
        
        var particleSize: Float {
            switch self {
            case .timeout: return 0.015
            case .connectionLost: return 0.020
            case .overload: return 0.025
            case .securityBreach: return 0.030
            case .hardwareFailure: return 0.010
            }
        }
    }
    
    // MARK: - Particle Properties
    public struct Particle {
        public var position: SIMD3<Float>
        public var velocity: SIMD3<Float>
        public var acceleration: SIMD3<Float>
        public var life: Float
        public var maxLife: Float
        public var size: Float
        public var color: UniversalColor
        public var type: FailureType
        
        public init(position: SIMD3<Float>, velocity: SIMD3<Float>, type: FailureType) {
            self.position = position
            self.velocity = velocity
            self.acceleration = SIMD3<Float>(0, -9.8, 0) // Gravity
            self.life = 1.0
            self.maxLife = 1.0
            self.size = type.particleSize
            self.color = type.particleColor
            self.type = type
        }
    }
    
    // MARK: - Properties
    private let scene: SCNScene
    private var particles: [Particle] = []
    private var particleNodes: [SCNNode] = []
    private var activeExplosions: [String: Explosion] = [:]
    private var updateTimer: Timer?
    
    @Published public var activeParticleCount: Int = 0
    @Published public var totalExplosions: Int = 0
    
    // Physics constants
    private let gravity: SIMD3<Float> = SIMD3<Float>(0, -9.8, 0)
    private let damping: Float = 0.98
    private let windForce: SIMD3<Float> = SIMD3<Float>(0.5, 0, 0.2)
    
    // MARK: - Explosion Types
    private struct Explosion {
        let id: String
        let position: SCNVector3
        let type: FailureType
        let startTime: TimeInterval
        let duration: TimeInterval
        var particles: [Particle]
        
        init(id: String, position: SCNVector3, type: FailureType) {
            self.id = id
            self.position = position
            self.type = type
            self.startTime = Date().timeIntervalSince1970
            self.duration = 3.0
            self.particles = []
        }
    }
    
    // MARK: - Initialization
    public init(scene: SCNScene) {
        self.scene = scene
        startPhysicsLoop()
    }
    
    // MARK: - Public Interface
    
    /// Triggers a connection failure explosion at specified position
    public func triggerFailure(at position: SCNVector3, type: FailureType = .connectionLost, nodeId: String? = nil) {
        let explosionId = nodeId ?? "explosion_\(Date().timeIntervalSince1970)"
        
        // Create explosion
        let explosion = Explosion(id: explosionId, position: position, type: type)
        activeExplosions[explosionId] = explosion
        
        // Generate particles
        generateParticles(for: explosion)
        
        // Create visual effects
        createExplosionEffects(explosion)
        
        totalExplosions += 1
    }
    
    /// Triggers multiple failures for cascade effect
    public func triggerCascadeFailures(at positions: [(SCNVector3, FailureType)]) {
        for (index, (position, type)) in positions.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                self.triggerFailure(at: position, type: type)
            }
        }
    }
    
    /// Creates a ripple effect from failure point
    public func createFailureRipple(at position: SCNVector3, type: FailureType) {
        let rippleNode = createRippleGeometry(at: position, type: type)
        
        // Animate ripple expansion
        let expandAction = SCNAction.scale(to: 3.0, duration: 1.5)
        let fadeAction = SCNAction.fadeOut(duration: 1.5)
        let groupAction = SCNAction.group([expandAction, fadeAction])
        
        rippleNode.runAction(groupAction) {
            rippleNode.removeFromParentNode()
        }
        
        scene.rootNode.addChildNode(rippleNode)
    }
    
    /// Triggers electromagnetic pulse effect
    public func triggerEMP(at position: SCNVector3, radius: Float = 2.0) {
        let empNode = createEMPGeometry(at: position, radius: radius)
        
        // Animate EMP pulse
        let scaleAction = SCNAction.scale(to: 0.1, duration: 0.5)
        let fadeAction = SCNAction.fadeOut(duration: 0.5)
        let groupAction = SCNAction.group([scaleAction, fadeAction])
        
        empNode.runAction(groupAction) {
            empNode.removeFromParentNode()
        }
        
        scene.rootNode.addChildNode(empNode)
    }
    
    // MARK: - Private Methods
    
    private func generateParticles(for explosion: Explosion) {
        let particleCount = explosion.type.particleCount
        
        for i in 0..<particleCount {
            // Generate random velocity in sphere
            let theta = Float.random(in: 0...(2 * .pi))
            let phi = Float.random(in: 0...(.pi))
            let force = explosion.type.explosionForce * Float.random(in: 0.5...1.0)
            
            let velocity = SIMD3<Float>(
                force * sin(phi) * cos(theta),
                force * cos(phi),
                force * sin(phi) * sin(theta)
            )
            
            let particle = Particle(
                position: SIMD3<Float>(
                    explosion.position.x,
                    explosion.position.y,
                    explosion.position.z
                ),
                velocity: velocity,
                type: explosion.type
            )
            
            particles.append(particle)
            
            // Create visual particle node
            let particleNode = createParticleNode(particle)
            particleNodes.append(particleNode)
            scene.rootNode.addChildNode(particleNode)
        }
        
        activeParticleCount += particleCount
    }
    
    private func createParticleNode(_ particle: Particle) -> SCNNode {
        let geometry = SCNSphere(radius: CGFloat(particle.size))
        
        let material = SCNMaterial()
        material.diffuse.contents = particle.color
        material.emission.contents = particle.color
        material.emission.intensity = 2.0
        material.lightingModel = .physicallyBased
        
        geometry.materials = [material]
        
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(
            particle.position.x,
            particle.position.y,
            particle.position.z
        )
        
        return node
    }
    
    private func createExplosionEffects(_ explosion: Explosion) {
        // Create flash effect
        let flashNode = SCNNode()
        flashNode.geometry = SCNSphere(radius: 0.1)
        
        let flashMaterial = SCNMaterial()
        flashMaterial.diffuse.contents = explosion.type.particleColor
        flashMaterial.emission.contents = explosion.type.particleColor
        flashMaterial.emission.intensity = 10.0
        
        flashNode.geometry?.materials = [flashMaterial]
        flashNode.position = explosion.position
        
        // Animate flash
        let flashAction = SCNAction.sequence([
            SCNAction.scale(to: 2.0, duration: 0.1),
            SCNAction.scale(to: 0.1, duration: 0.2),
            SCNAction.fadeOut(duration: 0.1)
        ])
        
        flashNode.runAction(flashAction) {
            flashNode.removeFromParentNode()
        }
        
        scene.rootNode.addChildNode(flashNode)
        
        // Create ripple effect
        createFailureRipple(at: explosion.position, type: explosion.type)
    }
    
    private func createRippleGeometry(at position: SCNVector3, type: FailureType) -> SCNNode {
        let ring = SCNTorus(ringRadius: 0.2, pipeRadius: 0.02)
        
        let material = SCNMaterial()
        material.diffuse.contents = type.particleColor
        material.emission.contents = type.particleColor
        material.emission.intensity = 1.5
        
        ring.materials = [material]
        
        let node = SCNNode(geometry: ring)
        node.position = position
        
        return node
    }
    
    private func createEMPGeometry(at position: SCNVector3, radius: Float) -> SCNNode {
        let sphere = SCNSphere(radius: CGFloat(radius))
        
        let material = SCNMaterial()
        material.diffuse.contents = UniversalColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.3)
        material.emission.contents = UniversalColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.5)
        
        sphere.materials = [material]
        
        let node = SCNNode(geometry: sphere)
        node.position = position
        
        return node
    }
    
    // MARK: - Physics Loop
    
    private func startPhysicsLoop() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            self.updatePhysics()
        }
    }
    
    private func updatePhysics() {
        let deltaTime: Float = 1.0/60.0
        
        // Update particles
        for i in particles.indices.reversed() {
            var particle = particles[i]
            
            // Apply physics
            particle.velocity += (gravity + windForce) * deltaTime
            particle.velocity *= damping
            particle.position += particle.velocity * deltaTime
            particle.life -= deltaTime / particle.maxLife
            
            // Update visual node
            if i < particleNodes.count {
                particleNodes[i].position = SCNVector3(
                    particle.position.x,
                    particle.position.y,
                    particle.position.z
                )
                
                // Fade out based on life
                particleNodes[i].opacity = CGFloat(particle.life)
            }
            
            // Remove dead particles
            if particle.life <= 0 {
                if i < particleNodes.count {
                    particleNodes[i].removeFromParentNode()
                    particleNodes.remove(at: i)
                }
                particles.remove(at: i)
                activeParticleCount -= 1
            } else {
                particles[i] = particle
            }
        }
        
        // Clean up old explosions
        let currentTime = Date().timeIntervalSince1970
        for (id, explosion) in activeExplosions {
            if currentTime - explosion.startTime > explosion.duration {
                activeExplosions.removeValue(forKey: id)
            }
        }
    }
    
    // MARK: - Performance Optimization
    
    /// Limits particle count for performance
    public func setMaxParticles(_ maxCount: Int) {
        if particles.count > maxCount {
            let excessCount = particles.count - maxCount
            for i in 0..<excessCount {
                if i < particleNodes.count {
                    particleNodes[i].removeFromParentNode()
                }
            }
            particles.removeLast(excessCount)
            particleNodes.removeLast(excessCount)
            activeParticleCount = maxCount
        }
    }
    
    /// Clears all particles and explosions
    public func clearAll() {
        for node in particleNodes {
            node.removeFromParentNode()
        }
        
        particles.removeAll()
        particleNodes.removeAll()
        activeExplosions.removeAll()
        activeParticleCount = 0
    }
    
    deinit {
        updateTimer?.invalidate()
        clearAll()
    }
}
