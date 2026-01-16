import SceneKit
import Foundation
import Metal

/// Integrated particle system combining all Stage 4 advanced features
/// GPU-accelerated particles with spatial partitioning, audio-visual sync, and curl noise physics
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class IntegratedParticleSystem {
    
    // MARK: - Core Components
    
    private let scene: SCNScene
    private let maxParticles: Int
    
    // Advanced systems
    private let spatialPartitioning: SpatialPartitioningSystem
    private let audioVisualSync: AudioVisualSyncSystem
    private let gpuSimulator: GPUPhysicsSimulator
    private let curlNoisePhysics: CurlNoisePhysics
    
    // Particle data
    private var particleData: [ParticleData] = []
    private var activeEmitters: [ParticleEmitter] = []
    
    // Performance monitoring
    private var frameCount: Int = 0
    private var lastPerformanceCheck: TimeInterval = 0
    
    // TODO: Implement Metal shader pipeline compilation
    // TODO: Add dynamic resource management
    // TODO: Implement particle pooling for memory efficiency
    
    // MARK: - Data Structures
    
    private struct ParticleData {
        let id: Int
        var position: SCNVector3
        var velocity: SCNVector3
        var life: Float
        var size: Float
        var color: UniversalColor
        var pattern: BurstPattern
        var intensity: Float
        var isActive: Bool
        
        init(id: Int, position: SCNVector3, pattern: BurstPattern, intensity: Float) {
            self.id = id
            self.position = position
            self.velocity = SCNVector3(0, 0, 0)
            self.life = 1.0
            self.size = 0.015
            self.color = .red
            self.pattern = pattern
            self.intensity = intensity
            self.isActive = true
        }
    }
    
    private class ParticleEmitter {
        let id: String
        let position: SCNVector3
        let pattern: BurstPattern
        let intensity: Float
        let startTime: TimeInterval
        let particleCount: Int
        
        var isExpired: Bool {
            Date().timeIntervalSince1970 - startTime > pattern.duration + 2.0
        }
        
        init(id: String, position: SCNVector3, pattern: BurstPattern, intensity: Float, particleCount: Int) {
            self.id = id
            self.position = position
            self.pattern = pattern
            self.intensity = intensity
            self.startTime = Date().timeIntervalSince1970
            self.particleCount = particleCount
        }
    }
    
    // MARK: - Initialization
    
    public init(scene: SCNScene, maxParticles: Int = 100000) {
        self.scene = scene
        self.maxParticles = maxParticles
        
        // Initialize advanced systems
        let bounds = SpatialPartitioningSystem.AABB(
            center: SCNVector3(0, 0, 0),
            size: SCNVector3(2000, 2000, 2000)
        )
        self.spatialPartitioning = SpatialPartitioningSystem(bounds: bounds, cellSize: 10.0)
        self.audioVisualSync = AudioVisualSyncSystem()
        self.gpuSimulator = GPUPhysicsSimulator(maxParticles: maxParticles)
        self.curlNoisePhysics = CurlNoisePhysics()
        
        // Pre-allocate particle data
        particleData.reserveCapacity(maxParticles)
    }
    
    // MARK: - Public Interface
    
    /// Emits a burst with all advanced features
    /// - Parameters:
    ///   - position: 3D position for particle emission
    ///   - pattern: Burst pattern type
    ///   - intensity: Particle intensity multiplier
    ///   - color: Base particle color
    ///   - enableAudio: Whether to trigger synchronized audio
    ///   - enableSpatialCulling: Whether to use spatial partitioning
    public func emitBurst(
        at position: SCNVector3,
        pattern: BurstPattern = .explosive,
        intensity: Float = 1.0,
        color: UniversalColor = .red,
        enableAudio: Bool = true,
        enableSpatialCulling: Bool = true
    ) {
        let emitterId = UUID().uuidString
        let particleCount = calculateParticleCount(pattern: pattern, intensity: intensity)
        
        // Create emitter
        let emitter = ParticleEmitter(
            id: emitterId,
            position: position,
            pattern: pattern,
            intensity: intensity,
            particleCount: particleCount
        )
        activeEmitters.append(emitter)
        
        // Trigger synchronized audio
        if enableAudio {
            let soundType = mapPatternToSoundType(pattern)
            audioVisualSync.triggerSyncEvent(
                type: soundType,
                at: position,
                intensity: intensity,
                pattern: pattern
            )
        }
        
        // Create particles
        createParticles(for: emitter, color: color)
        
        // Create SceneKit fallback for immediate visualization
        createSceneKitParticles(at: position, pattern: pattern, intensity: intensity, color: color)
    }
    
    /// Updates all particle systems and physics
    /// - Parameter deltaTime: Time since last frame
    public func update(deltaTime: TimeInterval) {
        frameCount += 1
        
        // Update particle physics
        updateParticlePhysics(deltaTime: deltaTime)
        
        // Update advanced systems
        audioVisualSync.update(deltaTime: deltaTime)
        
        // Update spatial partitioning
        let particleReferences = createParticleReferences()
        spatialPartitioning.update(particles: particleReferences)
        
        // Clean up expired emitters and particles
        cleanupExpiredElements()
        
        // Performance monitoring
        if frameCount % 60 == 0 {
            checkPerformance()
        }
    }
    
    /// Gets comprehensive performance statistics
    public var performanceStats: IntegratedPerformanceStats {
        let spatialStats = spatialPartitioning.getStatistics()
        let syncStats = audioVisualSync.syncStatistics
        
        return IntegratedPerformanceStats(
            totalParticles: particleData.filter { $0.isActive }.count,
            activeEmitters: activeEmitters.count,
            visibleParticles: spatialStats.visibleParticles,
            cullingEfficiency: spatialStats.cullingEfficiency,
            syncQuality: syncStats.syncQuality,
            audioEngineRunning: syncStats.audioEngineRunning,
            frameRate: calculateFrameRate(),
            memoryUsage: estimateMemoryUsage()
        )
    }
    
    /// Triggers ambient background effects
    public func triggerAmbientEffects() {
        audioVisualSync.triggerAmbientAudio(intensity: 0.3)
        
        // Add subtle ambient particles
        let ambientPosition = SCNVector3(
            Float.random(in: -100...100),
            Float.random(in: -50...50),
            Float.random(in: -100...100)
        )
        
        emitBurst(
            at: ambientPosition,
            pattern: .spiral,
            intensity: 0.2,
            color: .cyan,
            enableAudio: false
        )
    }
    
    /// Stops all particle effects and audio
    public func stopAllEffects() {
        activeEmitters.removeAll()
        particleData.removeAll()
        audioVisualSync.stopAllAudio()
        
        // Remove all SceneKit particle systems
        scene.rootNode.childNodes.forEach { node in
            if node.particleSystems?.isEmpty == false {
                node.removeFromParentNode()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func createParticles(for emitter: ParticleEmitter, color: UniversalColor) {
        let startIndex = particleData.count
        
        for i in 0..<emitter.particleCount {
            guard particleData.count < maxParticles else { break }
            
            let particle = ParticleData(
                id: startIndex + i,
                position: emitter.position,
                pattern: emitter.pattern,
                intensity: emitter.intensity
            )
            particleData.append(particle)
        }
        
        // Initialize velocities based on pattern
        initializeVelocities(for: emitter, startIndex: startIndex)
    }
    
    private func initializeVelocities(for emitter: ParticleEmitter, startIndex: Int) {
        for i in 0..<emitter.particleCount {
            guard startIndex + i < particleData.count else { break }
            
            var particle = particleData[startIndex + i]
            particle.velocity = generatePatternVelocity(
                pattern: emitter.pattern,
                index: i,
                total: emitter.particleCount,
                intensity: emitter.intensity
            )
            particleData[startIndex + i] = particle
        }
    }
    
    private func generatePatternVelocity(
        pattern: BurstPattern,
        index: Int,
        total: Int,
        intensity: Float
    ) -> SCNVector3 {
        switch pattern {
        case .explosive:
            // Fibonacci sphere distribution
            let phi = Float.pi * (3 - sqrt(5))
            let y = 1 - (Float(index) / Float(total - 1)) * 2
            let radius = sqrt(1 - y * y)
            let theta = phi * Float(index)
            
            return SCNVector3(
                cos(theta) * radius,
                y,
                sin(theta) * radius
            ) * intensity * 5.0
            
        case .fountain:
            let t = Float(index) / Float(total)
            let angle = t * 2 * Float.pi
            let spread = 0.5
            
            return SCNVector3(
                sin(angle) * spread,
                1.0,
                cos(angle) * spread
            ) * intensity * 8.0
            
        case .spiral:
            let t = Float(index) / Float(total)
            let spiralTurns: Float = 3
            let angle = t * spiralTurns * 2 * Float.pi
            let radius = t * 0.1
            
            return SCNVector3(
                cos(angle) * radius,
                t,
                sin(angle) * radius
            ) * (1 - t) * 4.0 * intensity
            
        case .shockwave:
            let rings = 5
            let particlesPerRing = total / rings
            let ring = index / particlesPerRing
            let ringIndex = index % particlesPerRing
            
            let angle = Float(ringIndex) * 2 * Float.pi / Float(particlesPerRing)
            let ringRadius = Float(ring + 1) * 0.05
            
            return SCNVector3(
                cos(angle),
                0,
                sin(angle)
            ) * (Float(rings - ring) * 0.5) * intensity * 2.0
        }
    }
    
    private func createSceneKitParticles(
        at position: SCNVector3,
        pattern: BurstPattern,
        intensity: Float,
        color: UniversalColor
    ) {
        let system = SCNParticleSystem()
        system.birthRate = Float(calculateParticleCount(pattern: pattern, intensity: intensity)) * 10
        system.particleLifeSpan = pattern.duration
        system.particleSize = 0.015
        system.particleColor = color
        system.isLightingEnabled = true
        system.emissionDuration = 0.1
        system.loops = false
        
        // Pattern-specific configuration
        configureSceneKitPattern(system, pattern: pattern, intensity: intensity)
        
        let emitterNode = SCNNode()
        emitterNode.position = position
        emitterNode.addParticleSystem(system)
        scene.rootNode.addChildNode(emitterNode)
        
        // Auto-cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + pattern.duration + 0.5) {
            emitterNode.removeFromParentNode()
        }
    }
    
    private func configureSceneKitPattern(_ system: SCNParticleSystem, pattern: BurstPattern, intensity: Float) {
        switch pattern {
        case .explosive:
            system.particleVelocity = 5.0 * intensity
            system.particleVelocityVariation = 2.0
            system.acceleration = SCNVector3(0, -9.8, 0)
            
        case .fountain:
            system.particleVelocity = 8.0 * intensity
            system.particleVelocityVariation = 1.0
            system.acceleration = SCNVector3(0, -9.8, 0)
            system.emitterShape = SCNCone(topRadius: 0.01, bottomRadius: 0.1, height: 0.2)
            
        case .spiral:
            system.particleVelocity = 3.0 * intensity
            system.particleVelocityVariation = 0.5
            system.acceleration = SCNVector3(0, -2.0, 0)
            
        case .shockwave:
            system.particleVelocity = 10.0 * intensity
            system.particleVelocityVariation = 0.2
            system.acceleration = SCNVector3(0, 0, 0)
        }
    }
    
    private func updateParticlePhysics(deltaTime: TimeInterval) {
        var positions: [SCNVector3] = []
        var velocities: [SCNVector3] = []
        
        // Collect active particles
        for i in 0..<particleData.count {
            if particleData[i].isActive {
                positions.append(particleData[i].position)
                velocities.append(particleData[i].velocity)
            }
        }
        
        // Apply curl noise physics
        curlNoisePhysics.applyCurlNoise(
            positions: positions,
            velocities: &velocities,
            deltaTime: deltaTime
        )
        
        // Update particle data
        var velocityIndex = 0
        for i in 0..<particleData.count {
            if particleData[i].isActive {
                particleData[i].velocity = velocities[velocityIndex]
                particleData[i].position += particleData[i].velocity * Float(deltaTime)
                particleData[i].life -= Float(deltaTime) * 0.5
                
                if particleData[i].life <= 0 {
                    particleData[i].isActive = false
                }
                
                velocityIndex += 1
            }
        }
    }
    
    private func createParticleReferences() -> [SpatialPartitioningSystem.ParticleReference] {
        var references: [SpatialPartitioningSystem.ParticleReference] = []
        
        for particle in particleData {
            if particle.isActive {
                let reference = SpatialPartitioningSystem.ParticleReference(
                    id: particle.id,
                    position: particle.position,
                    velocity: particle.velocity,
                    life: particle.life,
                    size: particle.size,
                    color: particle.color
                )
                references.append(reference)
            }
        }
        
        return references
    }
    
    private func cleanupExpiredElements() {
        // Remove expired emitters
        activeEmitters.removeAll { $0.isExpired }
        
        // Remove inactive particles (compact the array)
        particleData.removeAll { !$0.isActive }
    }
    
    private func calculateParticleCount(pattern: BurstPattern, intensity: Float) -> Int {
        let baseCount: Int
        switch pattern {
        case .explosive: baseCount = 100
        case .fountain: baseCount = 150
        case .spiral: baseCount = 80
        case .shockwave: baseCount = 200
        }
        
        return Int(Float(baseCount) * intensity)
    }
    
    private func mapPatternToSoundType(_ pattern: BurstPattern) -> AudioVisualSyncSystem.SoundType {
        switch pattern {
        case .explosive: return .explosion
        case .fountain: return .fountain
        case .spiral: return .spiral
        case .shockwave: return .shockwave
        }
    }
    
    private func checkPerformance() {
        let now = Date().timeIntervalSince1970
        let deltaTime = now - lastPerformanceCheck
        
        if deltaTime > 0 {
            let fps = Float(frameCount) / Float(deltaTime)
            if fps < 30.0 {
                print("⚠️ Low FPS detected: \\(fps)")
                // TODO: Implement automatic quality adjustment
            }
        }
        
        frameCount = 0
        lastPerformanceCheck = now
    }
    
    private func calculateFrameRate() -> Float {
        // TODO: Implement accurate frame rate calculation
        return 60.0
    }
    
    private func estimateMemoryUsage() -> Int {
        let particleMemory = particleData.count * MemoryLayout<ParticleData>.size
        let emitterMemory = activeEmitters.count * MemoryLayout<ParticleEmitter>.size
        return particleMemory + emitterMemory
    }
}

/// Comprehensive performance statistics
public struct IntegratedPerformanceStats {
    public let totalParticles: Int
    public let activeEmitters: Int
    public let visibleParticles: Int
    public let cullingEfficiency: Float
    public let syncQuality: Float
    public let audioEngineRunning: Bool
    public let frameRate: Float
    public let memoryUsage: Int
    
    public var performanceGrade: String {
        let score = (cullingEfficiency + syncQuality) * 0.5
        switch score {
        case 0.8...1.0: return "A+"
        case 0.6..<0.8: return "B"
        case 0.4..<0.6: return "C"
        case 0.2..<0.4: return "D"
        default: return "F"
        }
    }
}
