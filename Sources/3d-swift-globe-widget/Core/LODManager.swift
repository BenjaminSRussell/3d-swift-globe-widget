import SceneKit
import Foundation
import Combine

/// Advanced Level of Detail (LOD) manager for performance optimization
/// Phase 3: Intelligent LOD system for network topology and particle effects
/// Stage 5: Enhanced with camera-aware LOD adjustments for auto-fitting system
@available(iOS 15.0, macOS 12.0, *)
public class LODManager: ObservableObject {
    
    // Stage 5: Camera system integration
    private var cameraNode: SCNNode?
    private var lastCameraPosition: SCNVector3 = SCNVector3Zero
    private var cameraMovementThreshold: Float = 0.5
    
    // Stage 6: Performance optimization components
    private let memoryManager: MemoryManager
    private let performanceMonitor: PerformanceMonitor
    
    // MARK: - LOD Levels
    public enum LODLevel: Int, CaseIterable {
        case ultra = 0    // Maximum detail (close up)
        case high = 1     // High detail (near)
        case medium = 2   // Medium detail (medium distance)
        case low = 3      // Low detail (far)
        case minimal = 4  // Minimal detail (very far)
        
        var distanceThreshold: Float {
            switch self {
            case .ultra: return 2.0
            case .high: return 5.0
            case .medium: return 10.0
            case .low: return 20.0
            case .minimal: return 50.0
            }
        }
        
        var arcSegmentCount: Int {
            switch self {
            case .ultra: return 64
            case .high: return 32
            case .medium: return 16
            case .low: return 8
            case .minimal: return 4
            }
        }
        
        var particleCount: Int {
            switch self {
            case .ultra: return 200
            case .high: return 100
            case .medium: return 50
            case .low: return 20
            case .minimal: return 5
            }
        }
        
        var labelVisibility: Bool {
            switch self {
            case .ultra, .high: return true
            case .medium, .low, .minimal: return false
            }
        }
        
        var dataFlowAnimation: Bool {
            switch self {
            case .ultra, .high: return true
            case .medium: return false
            case .low, .minimal: return false
            }
        }
    }
    
    // MARK: - Properties
    private let cameraNode: SCNNode
    private var currentLOD: LODLevel = .high
    private var lodUpdateTimer: Timer?
    
    // Stage 6: Performance optimization components
    private let memoryManager: MemoryManager
    private let performanceMonitor: PerformanceMonitor
    
    @Published public var currentLODLevel: LODLevel = .high
    @Published public var isAggressiveMode: Bool = false
    
    // LOD caches for performance
    private var arcGeometryCache: [LODLevel: SCNGeometry] = [:]
    private var particleSystemCache: [LODLevel: SCNParticleSystem] = [:]
    
    // Performance thresholds
    private let targetFPS: Double = 60.0
    private let minAcceptableFPS: Double = 30.0
    
    // MARK: - Initialization
    
    public init(cameraNode: SCNNode? = nil) {
        self.cameraNode = cameraNode
        self.memoryManager = MemoryManager()
        self.performanceMonitor = PerformanceMonitor()
        
        // Stage 5: Initialize camera tracking
        if let camera = cameraNode {
            self.lastCameraPosition = camera.position
        }
        
        // Stage 6: Initialize performance monitoring
        startPerformanceTracking()
        
        setupLODCaches()
        startLODUpdates()
    }
    
    // Stage 5: Camera system integration
    public func setCameraNode(_ camera: SCNNode) {
        self.cameraNode = camera
        self.lastCameraPosition = camera.position
    }
    
    // Stage 5: LOD-aware bounds calculations for camera auto-fitting
    public func calculateOptimalBounds(for nodes: [SCNNode]) -> (center: SCNVector3, radius: Float) {
        guard !nodes.isEmpty else { return (SCNVector3Zero, 1.0) }
        
        let currentLOD = currentLODLevel
        let lodMultiplier = currentLOD.distanceThreshold / 10.0
        
        var minBounds = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxBounds = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        
        for node in nodes {
            let worldPos = node.worldPosition
            minBounds.x = min(minBounds.x, worldPos.x)
            minBounds.y = min(minBounds.y, worldPos.y)
            minBounds.z = min(minBounds.z, worldPos.z)
            
            maxBounds.x = max(maxBounds.x, worldPos.x)
            maxBounds.y = max(maxBounds.y, worldPos.y)
            maxBounds.z = max(maxBounds.z, worldPos.z)
        }
        
        let center = SCNVector3(
            (minBounds.x + maxBounds.x) / 2,
            (minBounds.y + maxBounds.y) / 2,
            (minBounds.z + maxBounds.z) / 2
        )
        
        let size = SCNVector3(
            maxBounds.x - minBounds.x,
            maxBounds.y - minBounds.y,
            maxBounds.z - minBounds.z
        )
        
        let radius = max(max(size.x, size.y), size.z) * lodMultiplier
        
        return (center, radius)
    }
    
    // Stage 6: Performance tracking
    private func startPerformanceTracking() {
        performanceMonitor.start()
        
        // Monitor FPS and adjust LOD dynamically
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.adjustLODBasedOnPerformance()
            }
            .store(in: &cancellables)
    }
    
    // Stage 5: Dynamic LOD scaling based on camera performance metrics
    private func adjustLODBasedOnPerformance() {
        let currentFPS = performanceMonitor.currentFPS
        
        if currentFPS < minAcceptableFPS {
            // Performance is poor, reduce LOD
            if currentLODLevel.rawValue < LODLevel.allCases.count - 1 {
                currentLODLevel = LODLevel(rawValue: currentLODLevel.rawValue + 1) ?? .low
            }
        } else if currentFPS > targetFPS + 10 {
            // Performance is excellent, can increase LOD
            if currentLODLevel.rawValue > 0 {
                currentLODLevel = LODLevel(rawValue: currentLODLevel.rawValue - 1) ?? .high
            }
        }
    }
    
    // Stage 5: Camera movement detection for LOD updates
    private func detectCameraMovement() -> Bool {
        guard let camera = cameraNode else { return false }
        
        let distance = calculateDistance(from: lastCameraPosition, to: camera.position)
        if distance > cameraMovementThreshold {
            lastCameraPosition = camera.position
            return true
        }
        return false
    }
    
    /// Updates LOD for all visible objects based on camera distance
    public func updateLOD(for node: SCNNode) {
        let distance = calculateDistance(from: cameraNode.position, to: node.position)
        let newLOD = determineLOD(for: distance)
        
        if newLOD != currentLOD {
            updateLODLevel(newLOD)
        }
        
        applyLOD(to: node, level: newLOD)
    }
    
    /// Updates LOD for multiple nodes efficiently
    public func updateLODBatch(for nodes: [SCNNode]) {
        let newLOD = determineGlobalLOD(for: nodes)
        
        if newLOD != currentLOD {
            updateLODLevel(newLOD)
        }
        
        for node in nodes {
            applyLOD(to: node, level: newLOD)
        }
    }
    
    /// Updates LOD for arc system
    public func updateArcLOD(arcSystem: ArcSystem) {
        arcSystem.updateLOD(cameraPosition: cameraNode.position)
    }
    
    /// Updates LOD for particle systems
    public func updateParticleLOD(particleSystem: ParticleSystem) {
        let maxParticles = currentLOD.particleCount
        particleSystem.setMaxParticleCount(maxParticles)
    }
    
    /// Aggressive LOD mode for performance optimization
    public func aggressiveLOD() {
        isAggressiveMode = true
        
        // Force minimal LOD
        updateLODLevel(.minimal)
        
        // Reduce update frequency
        lodUpdateTimer?.invalidate()
        lodUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.performLODUpdate()
        }
    }
    
    /// Disables aggressive LOD mode
    public func disableAggressiveLOD() {
        isAggressiveMode = false
        
        // Restore normal update frequency
        lodUpdateTimer?.invalidate()
        startLODUpdates()
    }
    
    // MARK: - Private Methods
    
    private func setupLODCaches() {
        // Pre-generate LOD geometries for performance
        for level in LODLevel.allCases {
            arcGeometryCache[level] = createArcGeometry(for: level)
            particleSystemCache[level] = createParticleSystem(for: level)
        }
    }
    
    private func startLODUpdates() {
        lodUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/10.0, repeats: true) { _ in
            self.performLODUpdate()
        }
    }
    
    private func performLODUpdate() {
        // Check performance and adjust LOD accordingly
        let currentFPS = performanceMonitor?.currentFPS ?? targetFPS
        
        if currentFPS < minAcceptableFPS && !isAggressiveMode {
            // Performance is poor, reduce LOD
            let nextLOD = LODLevel(rawValue: min(currentLOD.rawValue + 1, LODLevel.minimal.rawValue)) ?? .minimal
            updateLODLevel(nextLOD)
        } else if currentFPS > targetFPS - 10 && isAggressiveMode {
            // Performance is good, can increase LOD
            let nextLOD = LODLevel(rawValue: max(currentLOD.rawValue - 1, LODLevel.ultra.rawValue)) ?? .ultra
            updateLODLevel(nextLOD)
        }
    }
    
    private func determineLOD(for distance: Float) -> LODLevel {
        for level in LODLevel.allCases {
            if distance <= level.distanceThreshold {
                return level
            }
        }
        return .minimal
    }
    
    private func determineGlobalLOD(for nodes: [SCNNode]) -> LODLevel {
        var totalDistance: Float = 0
        var nodeCount = 0
        
        for node in nodes {
            let distance = calculateDistance(from: cameraNode.position, to: node.position)
            totalDistance += distance
            nodeCount += 1
        }
        
        let averageDistance = nodeCount > 0 ? totalDistance / Float(nodeCount) : 0
        return determineLOD(for: averageDistance)
    }
    
    private func updateLODLevel(_ newLOD: LODLevel) {
        currentLOD = newLOD
        currentLODLevel = newLOD
        
        // Notify performance monitor
        performanceMonitor?.lodChanged(to: newLOD)
    }
    
    private func applyLOD(to node: SCNNode, level: LODLevel) {
        // Update geometry LOD
        if node.name?.hasPrefix("arc_") == true {
            updateArcGeometry(node, level: level)
        }
        
        // Update particle systems
        node.particleSystems?.forEach { particleSystem in
            updateParticleSystem(particleSystem, level: level)
        }
        
        // Update labels
        if node.name?.hasPrefix("label_") == true {
            node.isHidden = !level.labelVisibility
        }
        
        // Update data flow animations
        if node.name?.hasPrefix("dataflow_") == true {
            node.isHidden = !level.dataFlowAnimation
        }
    }
    
    private func updateArcGeometry(_ node: SCNNode, level: LODLevel) {
        guard let cachedGeometry = arcGeometryCache[level] else { return }
        
        // Apply cached geometry with smooth transition
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.2
        node.geometry = cachedGeometry
        SCNTransaction.commit()
    }
    
    private func updateParticleSystem(_ particleSystem: SCNParticleSystem, level: LODLevel) {
        particleSystem.birthRate = Float(level.particleCount)
        particleSystem.particleLifeSpan = level == .minimal ? 1.0 : 2.0
        particleSystem.particleSize = level == .minimal ? 0.01 : 0.02
    }
    
    private func createArcGeometry(for level: LODLevel) -> SCNGeometry {
        let tube = SCNTube(radius: 0.002, height: 1.0)
        tube.heightSegmentCount = level.arcSegmentCount
        tube.radialSegmentCount = max(4, level.arcSegmentCount / 4)
        
        // Add material
        let material = SCNMaterial()
        material.diffuse.contents = UniversalColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.8)
        material.lightingModel = .physicallyBased
        
        tube.materials = [material]
        
        return tube
    }
    
    private func createParticleSystem(for level: LODLevel) -> SCNParticleSystem {
        let particleSystem = SCNParticleSystem()
        particleSystem.particleImage = #imageLiteral(resourceName: "particle")
        particleSystem.birthRate = Float(level.particleCount)
        particleSystem.particleLifeSpan = 2.0
        particleSystem.particleSize = 0.02
        particleSystem.particleColor = UniversalColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.8)
        
        return particleSystem
    }
    
    private func calculateDistance(from fromPoint: SCNVector3, to toPoint: SCNVector3) -> Float {
        let dx = fromPoint.x - toPoint.x
        let dy = fromPoint.y - toPoint.y
        let dz = fromPoint.z - toPoint.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    
    // MARK: - Performance Monitoring
    
    private class PerformanceMonitor {
        private var frameCount: Int = 0
        private var lastTimestamp: CFTimeInterval = 0
        private var currentFPS: Double = 60.0
        
        var currentFPS: Double {
            return currentFPS
        }
        
        init() {
            startMonitoring()
        }
        
        private func startMonitoring() {
            lastTimestamp = CACurrentMediaTime()
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.updateFPS()
            }
        }
        
        private func updateFPS() {
            let currentTime = CACurrentMediaTime()
            let deltaTime = currentTime - lastTimestamp
            
            if deltaTime > 0 {
                currentFPS = Double(frameCount) / deltaTime
            }
            
            frameCount = 0
            lastTimestamp = currentTime
        }
        
        func lodChanged(to level: LODLevel) {
            // Log LOD changes for debugging
            print("LOD changed to: \(level)")
        }
        
        func incrementFrameCount() {
            frameCount += 1
        }
    }
    
    // MARK: - Memory Management
    
    /// Clears LOD caches to free memory
    public func clearCaches() {
        arcGeometryCache.removeAll()
        particleSystemCache.removeAll()
    }
    
    /// Rebuilds LOD caches
    public func rebuildCaches() {
        clearCaches()
        setupLODCaches()
    }
    
    deinit {
        lodUpdateTimer?.invalidate()
        clearCaches()
    }
}

// MARK: - Extensions

extension LODManager.LODLevel: CustomStringConvertible {
    public var description: String {
        switch self {
        case .ultra: return "Ultra"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .minimal: return "Minimal"
        }
    }
}
