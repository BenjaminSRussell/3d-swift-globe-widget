import Foundation
import SceneKit
import Combine

/// Advanced data flow visualization system for Stage 3
/// Simulates and renders packet movement along network connections
@available(iOS 15.0, macOS 12.0, *)
public class DataFlowVisualizer: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var activeFlows: Set<String> = []
    @Published public var flowStatistics: [String: FlowStatistics] = [:]
    @Published public var visualizationMode: VisualizationMode = .particles
    
    public enum VisualizationMode {
        case particles, pulses, waves, heatMap
    }
    
    // MARK: - Flow Statistics
    public struct FlowStatistics {
        public let connectionId: String
        public let packetCount: Int
        public let bandwidth: Double
        public let latency: Double
        public let packetLoss: Double
        public let lastUpdate: Date
        
        public init(connectionId: String, packetCount: Int = 0, bandwidth: Double = 0, 
                   latency: Double = 0, packetLoss: Double = 0) {
            self.connectionId = connectionId
            self.packetCount = packetCount
            self.bandwidth = bandwidth
            self.latency = latency
            self.packetLoss = packetLoss
            self.lastUpdate = Date()
        }
    }
    
    // MARK: - Private Properties
    private let sceneView: SCNView
    private var particleSystems: [String: SCNParticleSystem] = [:]
    private var pulseNodes: [String: SCNNode] = [:]
    private var flowAnimations: [String: SCNAction] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Dependencies
    private let networkService: NetworkService
    private let networkTopologyRenderer: NetworkTopologyRenderer
    private let lodManager: LODManager
    
    // MARK: - Configuration
    private struct FlowConfig {
        static let particleSpeed: Float = 2.0
        static let particleSize: Float = 0.02
        static let pulseSpeed: Double = 1.5
        static let maxParticles: Int = 1000
        static let particleLifetime: Float = 3.0
    }
    
    // MARK: - Initialization
    public init(sceneView: SCNView, networkService: NetworkService, 
                networkTopologyRenderer: NetworkTopologyRenderer, lodManager: LODManager) {
        self.sceneView = sceneView
        self.networkService = networkService
        self.networkTopologyRenderer = networkTopologyRenderer
        self.lodManager = lodManager
        
        setupBindings()
        setupVisualizationSystem()
    }
    
    // MARK: - Setup Methods
    private func setupBindings() {
        // Bind to network topology updates
        networkTopologyRenderer.$visibleConnections
            .sink { [weak self] connections in
                self?.updateActiveFlows(connections)
            }
            .store(in: &cancellables)
        
        // Bind to LOD changes for performance optimization
        lodManager.$currentLOD
            .sink { [weak self] lod in
                self?.updateVisualizationQuality(for: lod)
            }
            .store(in: &cancellables)
    }
    
    private func setupVisualizationSystem() {
        // Initialize particle systems for different flow types
        setupParticleFlowSystem()
        
        // Setup pulse animation materials
        setupPulseSystem()
        
        // Configure wave propagation system
        setupWaveSystem()
        
        // Initialize heat map rendering
        setupHeatMapSystem()
    }
    
    private func setupParticleFlowSystem() {
        // Configure particle templates for different flow types
        // High bandwidth: dense, fast particles
        // Low bandwidth: sparse, slow particles
        // Error states: red particles
    }
    
    private func setupPulseSystem() {
        // Create pulse animation templates
        // Configure pulse materials with glow effects
        // Setup pulse timing based on bandwidth
    }
    
    private func setupWaveSystem() {
        // Initialize wave propagation shaders
        // Configure wave materials
        // Setup wave timing and amplitude
    }
    
    private func setupHeatMapSystem() {
        // Create heat map texture generation
        // Configure heat color gradients
        // Setup heat map update frequency
    }
    
    // MARK: - Public Methods
    
    /// Starts data flow visualization for a connection
    /// - Parameters:
    ///   - connectionId: ID of the connection
    ///   - flowData: Initial flow data
    public func startFlow(for connectionId: String, flowData: FlowData) {
        guard networkTopologyRenderer.visibleConnections.contains(connectionId) else { return }
        
        activeFlows.insert(connectionId)
        
        switch visualizationMode {
        case .particles:
            startParticleFlow(for: connectionId, data: flowData)
        case .pulses:
            startPulseFlow(for: connectionId, data: flowData)
        case .waves:
            startWaveFlow(for: connectionId, data: flowData)
        case .heatMap:
            startHeatMapFlow(for: connectionId, data: flowData)
        }
        
        updateFlowStatistics(connectionId: connectionId, data: flowData)
    }
    
    /// Updates data flow for a connection
    /// - Parameters:
    ///   - connectionId: ID of the connection
    ///   - flowData: Updated flow data
    public func updateFlow(for connectionId: String, flowData: FlowData) {
        guard activeFlows.contains(connectionId) else { return }
        
        switch visualizationMode {
        case .particles:
            updateParticleFlow(for: connectionId, data: flowData)
        case .pulses:
            updatePulseFlow(for: connectionId, data: flowData)
        case .waves:
            updateWaveFlow(for: connectionId, data: flowData)
        case .heatMap:
            updateHeatMapFlow(for: connectionId, data: flowData)
        }
        
        updateFlowStatistics(connectionId: connectionId, data: flowData)
    }
    
    /// Stops data flow visualization for a connection
    /// - Parameter connectionId: ID of the connection
    public func stopFlow(for connectionId: String) {
        activeFlows.remove(connectionId)
        
        // Remove all visualization components
        if let particleSystem = particleSystems[connectionId] {
            sceneView.scene?.rootNode.removeParticleSystem(particleSystem)
            particleSystems.removeValue(forKey: connectionId)
        }
        
        if let pulseNode = pulseNodes[connectionId] {
            pulseNode.removeFromParentNode()
            pulseNodes.removeValue(forKey: connectionId)
        }
        
        if let animation = flowAnimations[connectionId] {
            // Stop animation properly
            if let pulseNode = pulseNodes[connectionId] {
                pulseNode.removeAllActions()
            }
            flowAnimations.removeValue(forKey: connectionId)
        }
        
        flowStatistics.removeValue(forKey: connectionId)
    }
    
    /// Changes visualization mode
    /// - Parameter mode: New visualization mode
    public func setVisualizationMode(_ mode: VisualizationMode) {
        let activeConnectionIds = Array(activeFlows)
        
        // Stop all current flows
        for connectionId in activeConnectionIds {
            stopFlow(for: connectionId)
        }
        
        // Update mode
        visualizationMode = mode
        
        // Restart flows with new mode
        for connectionId in activeConnectionIds {
            if let stats = flowStatistics[connectionId] {
                let flowData = FlowData(
                    bandwidth: stats.bandwidth,
                    packetCount: stats.packetCount,
                    latency: stats.latency,
                    packetLoss: stats.packetLoss
                )
                startFlow(for: connectionId, flowData: flowData)
            }
        }
    }
    
    /// Triggers burst effect for high traffic
    /// - Parameters:
    ///   - connectionId: ID of the connection
    ///   - intensity: Burst intensity (0.0 - 1.0)
    public func triggerBurstEffect(for connectionId: String, intensity: Float) {
        switch visualizationMode {
        case .particles:
            triggerParticleBurst(for: connectionId, intensity: intensity)
        case .pulses:
            triggerPulseBurst(for: connectionId, intensity: intensity)
        case .waves:
            triggerWaveBurst(for: connectionId, intensity: intensity)
        case .heatMap:
            triggerHeatMapBurst(for: connectionId, intensity: intensity)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateActiveFlows(_ connections: Set<String>) {
        let currentIds = Set(activeFlows)
        let removedIds = currentIds.subtracting(connections)
        
        // Remove flows for disconnected connections
        for connectionId in removedIds {
            stopFlow(for: connectionId)
        }
    }
    
    private func updateVisualizationQuality(for lod: LODManager.LODLevel) {
        // Adjust particle count based on LOD
        updateParticleCount(for: lod)
        
        // Update animation speed based on performance
        updateAnimationSpeed(for: lod)
        
        // Disable complex effects for low LOD levels
        updateComplexEffects(for: lod)
        
        switch lod {
        case .ultra, .high:
            // Full quality visualization
            break
        case .medium:
            // Reduced particle count
            break
        case .low, .minimal:
            // Minimal visualization or disabled
            if lod == .minimal {
                // Disable all data flow visualization
                disableAllVisualization()
            }
        }
    }
    
    private func updateParticleCount(for lod: LODManager.LODLevel) {
        let multiplier: Float
        switch lod {
        case .ultra: multiplier = 1.0
        case .high: multiplier = 0.75
        case .medium: multiplier = 0.5
        case .low: multiplier = 0.25
        case .minimal: multiplier = 0.1
        }
        
        // Update particle systems with new count
        for (connectionId, system) in particleSystems {
            system.birthRate = system.birthRate * multiplier
        }
    }
    
    private func updateAnimationSpeed(for lod: LODManager.LODLevel) {
        // Adjust animation speeds based on LOD
        let speedMultiplier: Double
        switch lod {
        case .ultra: speedMultiplier = 1.0
        case .high: speedMultiplier = 0.9
        case .medium: speedMultiplier = 0.8
        case .low: speedMultiplier = 0.6
        case .minimal: speedMultiplier = 0.4
        }
        
        // Update animation speeds
        for (connectionId, animation) in flowAnimations {
            animation.speed = Float(speedMultiplier)
        }
    }
    
    private func updateComplexEffects(for lod: LODManager.LODLevel) {
        // Disable complex effects for lower LOD levels
        if lod == .low || lod == .minimal {
            // Disable glow effects
            // Disable particle trails
            // Reduce material complexity
        }
    }
    
    private func disableAllVisualization() {
        // Stop all particle systems
        for system in particleSystems.values {
            system.birthRate = 0
        }
        
        // Remove all pulse nodes
        for node in pulseNodes.values {
            node.removeFromParentNode()
        }
        pulseNodes.removeAll()
    }
    
    // MARK: - Particle Flow Methods
    
    private func startParticleFlow(for connectionId: String, data: FlowData) {
        // Create particle system for connection
        let particleSystem = createParticleSystem(for: data)
        
        // Configure particle emission along arc path
        configureArcPathEmission(particleSystem, connectionId: connectionId)
        
        // Set particle properties based on flow data
        configureParticleProperties(particleSystem, data: data)
        
        sceneView.scene?.rootNode.addParticleSystem(particleSystem)
        particleSystems[connectionId] = particleSystem
    }
    
    private func updateParticleFlow(for connectionId: String, data: FlowData) {
        guard let particleSystem = particleSystems[connectionId] else { return }
        
        // Update particle emission rate based on bandwidth
        updateEmissionRate(particleSystem, bandwidth: data.bandwidth)
        
        // Adjust particle color based on latency
        updateParticleColor(particleSystem, latency: data.latency)
        
        // Modify particle size based on packet count
        updateParticleSize(particleSystem, packetCount: data.packetCount)
    }
    
    private func updateEmissionRate(_ system: SCNParticleSystem, bandwidth: Double) {
        // Scale emission rate based on bandwidth (0.1 to 10 particles/sec)
        let baseRate = 0.1
        let maxRate = 10.0
        let rate = baseRate + (bandwidth / 100) * (maxRate - baseRate)
        system.birthRate = Float(rate)
    }
    
    private func updateParticleColor(_ system: SCNParticleSystem, latency: Double) {
        // Color based on latency: green (good) to yellow (medium) to red (bad)
        let normalizedLatency = min(latency / 200, 1.0) // 200ms as max
        
        if normalizedLatency < 0.5 {
            // Green to yellow
            let t = normalizedLatency * 2
            system.particleColor = UniversalColor(
                red: t,
                green: 1.0,
                blue: 0.0
            ).cgColor
        } else {
            // Yellow to red
            let t = (normalizedLatency - 0.5) * 2
            system.particleColor = UniversalColor(
                red: 1.0,
                green: 1.0 - t,
                blue: 0.0
            ).cgColor
        }
    }
    
    private func updateParticleSize(_ system: SCNParticleSystem, packetCount: Int) {
        // Size based on packet count (0.01 to 0.05)
        let normalizedCount = min(Double(packetCount) / 1000, 1.0)
        let size = 0.01 + normalizedCount * 0.04
        system.particleSize = Float(size)
    }
    
    private func triggerParticleBurst(for connectionId: String, intensity: Float) {
        guard let particleSystem = particleSystems[connectionId] else { return }
        
        // Create burst of particles
        let originalBirthRate = particleSystem.birthRate
        let burstRate = originalBirthRate * intensity * 5.0
        
        // Temporarily increase birth rate
        particleSystem.birthRate = burstRate
        
        // Reset after burst duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            particleSystem.birthRate = originalBirthRate
        }
        
        // Use intensity to control burst size
        // Add special effects for burst
        if intensity > 0.8 {
            // Add glow effect for high intensity bursts
            particleSystem.particleIntensity = 2.0
        }
    }
    
    private func createParticleSystem(for data: FlowData) -> SCNParticleSystem {
        let system = SCNParticleSystem()
        
        // Configure particle system properties
        system.particleImage = UIImage(systemName: "circle.fill")
        system.birthRate = Float(data.bandwidth / 100) // Adjust based on bandwidth
        system.particleLifeSpan = FlowConfig.particleLifetime
        system.particleSize = FlowConfig.particleSize
        system.particleSizeVariation = 0.01
        
        // Set particle color based on latency/packet loss
        system.particleColor = data.latency > 100 ? UniversalColor.red.cgColor : UniversalColor.green.cgColor
        
        return system
    }
    
    private func configureArcPathEmission(_ system: SCNParticleSystem, connectionId: String) {
        // Configure particles to follow arc path
        // This would involve setting up a custom emitter shape
        // that follows the connection arc geometry
        
        // For now, use a simple spherical emission
        system.emitterShape = SCNSphere(radius: 0.1)
        system.emittingDirection = SCNVector3(0, 1, 0)
        system.spreadingAngle = 45.0
    }
    
    private func configureParticleProperties(_ system: SCNParticleSystem, data: FlowData) {
        // Configure particle properties based on flow data
        system.particleVelocity = Float(data.bandwidth / 10) // Speed based on bandwidth
        system.particleVelocityVariation = 0.5
        
        // Set particle behavior
        system.isAffectedByGravity = false
        system.isAffectedByPhysicsFields = false
        system.dampingFactor = 0.1
        
        // Add particle trails for high bandwidth
        if data.bandwidth > 50 {
            system.particleIntensity = 1.5
        }
    }
    
    // MARK: - Pulse Flow Methods
    
    private func startPulseFlow(for connectionId: String, data: FlowData) {
        // TODO: Create pulse node for connection
        // TODO: Configure pulse animation
        // TODO: Set pulse properties based on flow data
    }
    
    private func updatePulseFlow(for connectionId: String, data: FlowData) {
        // TODO: Update pulse speed based on bandwidth
        // TODO: Adjust pulse color based on latency
    }
    
    private func triggerPulseBurst(for connectionId: String, intensity: Float) {
        // TODO: Create rapid pulse sequence
        // TODO: Use intensity to control pulse frequency
    }
    
    // MARK: - Wave Flow Methods
    
    private func startWaveFlow(for connectionId: String, data: FlowData) {
        // TODO: Create wave propagation effect
        // TODO: Configure wave properties
    }
    
    private func updateWaveFlow(for connectionId: String, data: FlowData) {
        // TODO: Update wave amplitude based on bandwidth
        // TODO: Adjust wave frequency based on packet rate
    }
    
    private func triggerWaveBurst(for connectionId: String, intensity: Float) {
        // TODO: Create wave burst effect
    }
    
    // MARK: - Heat Map Flow Methods
    
    private func startHeatMapFlow(for connectionId: String, data: FlowData) {
        // TODO: Create heat map visualization
        // TODO: Configure heat map colors
    }
    
    private func updateHeatMapFlow(for connectionId: String, data: FlowData) {
        // TODO: Update heat intensity based on bandwidth
        // TODO: Adjust heat colors based on performance
    }
    
    private func triggerHeatMapBurst(for connectionId: String, intensity: Float) {
        // TODO: Create heat burst effect
    }
    
    private func updateFlowStatistics(connectionId: String, data: FlowData) {
        let stats = FlowStatistics(
            connectionId: connectionId,
            packetCount: data.packetCount,
            bandwidth: data.bandwidth,
            latency: data.latency,
            packetLoss: data.packetLoss
        )
        
        flowStatistics[connectionId] = stats
    }
    
    // MARK: - Cleanup
    
    public func cleanup() {
        // Remove all particle systems
        for system in particleSystems.values {
            sceneView.scene?.rootNode.removeParticleSystem(system)
        }
        
        // Remove all pulse nodes
        for node in pulseNodes.values {
            node.removeFromParentNode()
        }
        
        // Clear all data
        particleSystems.removeAll()
        pulseNodes.removeAll()
        flowAnimations.removeAll()
        activeFlows.removeAll()
        flowStatistics.removeAll()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

public struct FlowData {
    public let bandwidth: Double      // Mbps
    public let packetCount: Int
    public let latency: Double        // ms
    public let packetLoss: Double     // percentage (0-100)
    
    public init(bandwidth: Double, packetCount: Int = 0, latency: Double = 0, packetLoss: Double = 0) {
        self.bandwidth = bandwidth
        self.packetCount = packetCount
        self.latency = latency
        self.packetLoss = packetLoss
    }
}
