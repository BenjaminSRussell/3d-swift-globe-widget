import Foundation
import SceneKit
import Metal

/// Manages memory allocation, tracking, and cleanup for 3D globe visualization
/// Implements Stage 6 performance optimization requirements
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class MemoryManager: ObservableObject {
    
    // MARK: - Memory Budget Configuration
    public struct MemoryBudget {
        public static let geometry: Int64 = 200 * 1024 * 1024    // 200MB
        public static let textures: Int64 = 100 * 1024 * 1024     // 100MB
        public static let shaders: Int64 = 50 * 1024 * 1024       // 50MB
        public static let particles: Int64 = 100 * 1024 * 1024    // 100MB
        public static let misc: Int64 = 30 * 1024 * 1024          // 30MB
        public static let total: Int64 = 500 * 1024 * 1024        // 500MB
    }
    
    // MARK: - Memory Tracking
    @Published public var currentUsage: [String: Int64] = [
        "geometry": 0,
        "textures": 0,
        "shaders": 0,
        "particles": 0,
        "misc": 0
    ]
    
    @Published public var totalMemoryUsage: Int64 = 0
    @Published public var memoryPressureLevel: MemoryPressureLevel = .normal
    
    public enum MemoryPressureLevel {
        case normal, warning, critical
    }
    
    // MARK: - Resource Registries
    private var geometryRegistry: [String: GeometryEntry] = [:]
    private var textureRegistry: [String: TextureEntry] = [:]
    private var materialRegistry: [String: MaterialEntry] = [:]
    private var disposalQueue: [DisposalEntry] = []
    
    private struct GeometryEntry {
        let geometry: SCNGeometry
        let size: Int64
        let lastUsed: Date
        let useCount: Int
        let id: String
    }
    
    private struct TextureEntry {
        let texture: SCNMaterialProperty
        let size: Int64
        let lastUsed: Date
        let useCount: Int
        let id: String
    }
    
    private struct MaterialEntry {
        let material: SCNMaterial
        let size: Int64
        let lastUsed: Date
        let useCount: Int
        let id: String
    }
    
    private struct DisposalEntry {
        let id: String
        let type: ResourceType
        let timestamp: Date
    }
    
    private enum ResourceType {
        case geometry, texture, material
    }
    
    // MARK: - Performance Monitoring
    private var performanceTimer: Timer?
    @Published public var frameRate: Double = 60.0
    @Published public var drawCallCount: Int = 0
    
    // MARK: - Initialization
    public init() {
        startPerformanceMonitoring()
        startMemoryCleanupTimer()
    }
    
    deinit {
        performanceTimer?.invalidate()
        cleanupAllResources()
    }
    
    // MARK: - Geometry Management
    public func registerGeometry(id: String, geometry: SCNGeometry) -> Bool {
        let estimatedSize = estimateGeometrySize(geometry)
        
        guard canAllocate(category: "geometry", size: estimatedSize) else {
            print("⚠️ Memory budget exceeded for geometry: \(estimatedSize) bytes")
            return false
        }
        
        let entry = GeometryEntry(
            geometry: geometry,
            size: estimatedSize,
            lastUsed: Date(),
            useCount: 1,
            id: id
        )
        
        geometryRegistry[id] = entry
        updateUsage(category: "geometry", delta: estimatedSize)
        
        return true
    }
    
    public func getGeometry(id: String) -> SCNGeometry? {
        guard var entry = geometryRegistry[id] else { return nil }
        
        // Update usage tracking
        entry.useCount += 1
        geometryRegistry[id] = entry
        
        return entry.geometry
    }
    
    public func releaseGeometry(id: String) {
        guard let entry = geometryRegistry[id] else { return }
        
        entry.geometry.removeMaterial(at: 0)
        updateUsage(category: "geometry", delta: -entry.size)
        geometryRegistry.removeValue(forKey: id)
    }
    
    // MARK: - Texture Management
    public func registerTexture(id: String, texture: SCNMaterialProperty) -> Bool {
        let estimatedSize = estimateTextureSize(texture)
        
        guard canAllocate(category: "textures", size: estimatedSize) else {
            print("⚠️ Memory budget exceeded for textures: \(estimatedSize) bytes")
            return false
        }
        
        let entry = TextureEntry(
            texture: texture,
            size: estimatedSize,
            lastUsed: Date(),
            useCount: 1,
            id: id
        )
        
        textureRegistry[id] = entry
        updateUsage(category: "textures", delta: estimatedSize)
        
        return true
    }
    
    public func releaseTexture(id: String) {
        guard let entry = textureRegistry[id] else { return }
        
        updateUsage(category: "textures", delta: -entry.size)
        textureRegistry.removeValue(forKey: id)
    }
    
    // MARK: - Material Management
    public func registerMaterial(id: String, material: SCNMaterial) -> Bool {
        let estimatedSize = estimateMaterialSize(material)
        
        guard canAllocate(category: "shaders", size: estimatedSize) else {
            print("⚠️ Memory budget exceeded for materials: \(estimatedSize) bytes")
            return false
        }
        
        let entry = MaterialEntry(
            material: material,
            size: estimatedSize,
            lastUsed: Date(),
            useCount: 1,
            id: id
        )
        
        materialRegistry[id] = entry
        updateUsage(category: "shaders", delta: estimatedSize)
        
        return true
    }
    
    public func releaseMaterial(id: String) {
        guard let entry = materialRegistry[id] else { return }
        
        entry.material.shaderModifiers = [:]
        updateUsage(category: "shaders", delta: -entry.size)
        materialRegistry.removeValue(forKey: id)
    }
    
    // MARK: - Memory Budget Management
    private func canAllocate(category: String, size: Int64) -> Bool {
        let currentUsage = currentUsage[category] ?? 0
        let budget: Int64
        
        switch category {
        case "geometry": budget = MemoryBudget.geometry
        case "textures": budget = MemoryBudget.textures
        case "shaders": budget = MemoryBudget.shaders
        case "particles": budget = MemoryBudget.particles
        default: budget = MemoryBudget.misc
        }
        
        return currentUsage + size <= budget
    }
    
    private func updateUsage(category: String, delta: Int64) {
        currentUsage[category, default: 0] += delta
        totalMemoryUsage += delta
        updateMemoryPressureLevel()
    }
    
    private func updateMemoryPressureLevel() {
        let usagePercentage = Double(totalMemoryUsage) / Double(MemoryBudget.total)
        
        if usagePercentage > 0.9 {
            memoryPressureLevel = .critical
        } else if usagePercentage > 0.7 {
            memoryPressureLevel = .warning
        } else {
            memoryPressureLevel = .normal
        }
    }
    
    // MARK: - Automatic Cleanup
    private func startMemoryCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performMemoryCleanup()
            }
        }
    }
    
    public func performMemoryCleanup() {
        let cleanupThreshold = Date().addingTimeInterval(-60) // 1 minute ago
        
        // Clean up unused geometries
        for (id, entry) in geometryRegistry {
            if entry.lastUsed < cleanupThreshold && entry.useCount == 1 {
                scheduleDisposal(id: id, type: .geometry, delay: 0)
            }
        }
        
        // Clean up unused textures
        for (id, entry) in textureRegistry {
            if entry.lastUsed < cleanupThreshold && entry.useCount == 1 {
                scheduleDisposal(id: id, type: .texture, delay: 0)
            }
        }
        
        processDisposalQueue()
    }
    
    private func scheduleDisposal(id: String, type: ResourceType, delay: TimeInterval) {
        let entry = DisposalEntry(
            id: id,
            type: type,
            timestamp: Date().addingTimeInterval(delay)
        )
        disposalQueue.append(entry)
    }
    
    private func processDisposalQueue() {
        let now = Date()
        let toDispose = disposalQueue.filter { $0.timestamp <= now }
        
        for entry in toDispose {
            switch entry.type {
            case .geometry:
                releaseGeometry(id: entry.id)
            case .texture:
                releaseTexture(id: entry.id)
            case .material:
                releaseMaterial(id: entry.id)
            }
        }
        
        disposalQueue.removeAll { toDispose.contains($0) }
    }
    
    // MARK: - Performance Monitoring
    private func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        // This would integrate with SceneKit's performance statistics
        // For now, we'll simulate the monitoring
        if memoryPressureLevel == .critical {
            frameRate = max(30, frameRate - 5)
        } else {
            frameRate = min(60, frameRate + 1)
        }
    }
    
    // MARK: - Size Estimation
    private func estimateGeometrySize(_ geometry: SCNGeometry) -> Int64 {
        // Rough estimation based on vertex count
        let vertexCount = geometry.sources.first?.vectorCount ?? 0
        return Int64(vertexCount * 32) // 32 bytes per vertex (position + normal + UV)
    }
    
    private func estimateTextureSize(_ texture: SCNMaterialProperty) -> Int64 {
        // Default texture size estimation
        return 1024 * 1024 * 4 // 1MB RGBA texture
    }
    
    private func estimateMaterialSize(_ material: SCNMaterial) -> Int64 {
        // Estimate based on shader complexity
        let shaderComplexity = material.shaderModifiers.keys.count
        return Int64(shaderComplexity * 1024) // 1KB per shader modifier
    }
    
    // MARK: - Emergency Cleanup
    public func performEmergencyCleanup() {
        print("🚨 Performing emergency memory cleanup")
        
        // Release all non-critical resources
        let allGeometryIds = Array(geometryRegistry.keys)
        let allTextureIds = Array(textureRegistry.keys)
        let allMaterialIds = Array(materialRegistry.keys)
        
        for id in allGeometryIds {
            releaseGeometry(id: id)
        }
        
        for id in allTextureIds {
            releaseTexture(id: id)
        }
        
        for id in allMaterialIds {
            releaseMaterial(id: id)
        }
        
        // Force garbage collection
        autoreleasepool {
            // Clear any remaining references
        }
    }
    
    // MARK: - Resource Statistics
    public func getMemoryStatistics() -> MemoryStatistics {
        return MemoryStatistics(
            totalUsage: totalMemoryUsage,
            categoryUsage: currentUsage,
            pressureLevel: memoryPressureLevel,
            geometryCount: geometryRegistry.count,
            textureCount: textureRegistry.count,
            materialCount: materialRegistry.count
        )
    }
    
    public struct MemoryStatistics {
        public let totalUsage: Int64
        public let categoryUsage: [String: Int64]
        public let pressureLevel: MemoryPressureLevel
        public let geometryCount: Int
        public let textureCount: Int
        public let materialCount: Int
    }
    
    // MARK: - Cleanup
    private func cleanupAllResources() {
        performEmergencyCleanup()
        performanceTimer?.invalidate()
    }
}

// MARK: - Memory Leak Detection Extension
extension MemoryManager {
    
    public func startLeakDetection() {
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.detectMemoryLeaks()
            }
        }
    }
    
    private func detectMemoryLeaks() {
        let stats = getMemoryStatistics()
        
        // Check for unusual growth patterns
        if stats.totalUsage > MemoryBudget.total * 9 / 10 {
            print("⚠️ High memory usage detected: \(stats.totalUsage / 1024 / 1024)MB")
        }
        
        // Check for resource leaks
        if stats.geometryCount > 1000 {
            print("⚠️ Potential geometry leak: \(stats.geometryCount) geometries")
        }
        
        if stats.textureCount > 100 {
            print("⚠️ Potential texture leak: \(stats.textureCount) textures")
        }
    }
}
