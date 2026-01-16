import SceneKit
import Foundation

/// Object pooling system for geometries to prevent garbage collection and improve performance
/// TODO: Stage 6 - Integrate with MemoryManager for comprehensive resource management
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class GeometryPool: ObservableObject {
    
    // MARK: - Pool Storage
    private var pools: [String: PoolEntry] = [:]
    private var activeGeometries: [String: PooledGeometry] = [:]
    
    private struct PoolEntry {
        var available: [PooledGeometry]
        var active: Int
        var totalCreated: Int
        let name: String
    }
    
    private struct PooledGeometry {
        let geometry: SCNGeometry
        let poolId: String
        var isInUse: Bool = false
        var lastUsed: Date = Date()
    }
    
    // MARK: - Statistics
    @Published public var poolStatistics: [String: PoolStatistics] = [:]
    
    public struct PoolStatistics {
        public let available: Int
        public let active: Int
        public let totalCreated: Int
        public let utilization: Double
    }
    
    // MARK: - Memory Manager Integration
    private let memoryManager: MemoryManager
    
    public init(memoryManager: MemoryManager) {
        self.memoryManager = memoryManager
        setupStandardPools()
    }
    
    // MARK: - Pool Management
    public func createPool(name: String, initialSize: Int = 10, geometryFactory: @escaping () -> SCNGeometry?) {
        guard pools[name] == nil else {
            print("⚠️ Pool '\(name)' already exists")
            return
        }
        
        var available: [PooledGeometry] = []
        for i in 0..<initialSize {
            if let geometry = geometryFactory() {
                let pooledGeometry = PooledGeometry(
                    geometry: geometry,
                    poolId: "\(name)-\(i)"
                )
                available.append(pooledGeometry)
                
                // TODO: Stage 6 - Register with MemoryManager
                _ = memoryManager.registerGeometry(id: pooledGeometry.poolId, geometry: geometry)
            }
        }
        
        pools[name] = PoolEntry(
            available: available,
            active: 0,
            totalCreated: initialSize,
            name: name
        )
        
        print("✅ Created geometry pool '\(name)' with \(available.count) initial geometries")
    }
    
    public func acquire(from poolName: String) -> SCNGeometry? {
        guard var pool = pools[poolName] else {
            print("⚠️ Pool '\(poolName)' not found")
            return nil
        }
        
        let geometry: PooledGeometry
        
        if pool.available.isEmpty {
            // Create new geometry if pool is exhausted
            // TODO: Stage 6 - Check memory budget before creating
            if let newGeometry = createGeometryForPool(poolName) {
                geometry = newGeometry
                pool.totalCreated += 1
            } else {
                print("❌ Failed to create new geometry for pool '\(poolName)'")
                return nil
            }
        } else {
            geometry = pool.available.removeLast()
        }
        
        geometry.isInUse = true
        geometry.lastUsed = Date()
        pool.active += 1
        
        pools[poolName] = pool
        activeGeometries[geometry.poolId] = geometry
        
        updateStatistics()
        
        return geometry.geometry
    }
    
    public func release(_ geometry: SCNGeometry, from poolName: String) {
        guard var pool = pools[poolName] else {
            print("⚠️ Pool '\(poolName)' not found during release")
            return
        }
        
        // Find the geometry in active geometries
        guard let (poolId, pooledGeometry) = activeGeometries.first(where: { $0.value.geometry === geometry }) else {
            print("⚠️ Geometry not found in active geometries")
            return
        }
        
        // Reset geometry for reuse
        resetGeometry(geometry)
        
        // Return to pool
        var resetPooledGeometry = pooledGeometry
        resetPooledGeometry.isInUse = false
        resetPooledGeometry.lastUsed = Date()
        
        pool.available.append(resetPooledGeometry)
        pool.active -= 1
        
        pools[poolName] = pool
        activeGeometries.removeValue(forKey: poolId)
        
        updateStatistics()
    }
    
    // MARK: - Standard Pool Setup
    private func setupStandardPools() {
        // TODO: Stage 6 - Configure pools based on performance requirements
        createPool(name: "sphere") {
            SCNSphere(radius: 1.0, segments: 32)
        }
        
        createPool(name: "tube") {
            SCNCylinder(radius: 0.01, height: 1.0)
        }
        
        createPool(name: "plane") {
            SCNPlane(width: 1.0, height: 1.0)
        }
        
        print("✅ Standard geometry pools initialized")
    }
    
    private func createGeometryForPool(_ poolName: String) -> PooledGeometry? {
        let geometry: SCNGeometry?
        
        switch poolName {
        case "sphere":
            geometry = SCNSphere(radius: 1.0, segments: 32)
        case "tube":
            geometry = SCNCylinder(radius: 0.01, height: 1.0)
        case "plane":
            geometry = SCNPlane(width: 1.0, height: 1.0)
        default:
            geometry = nil
        }
        
        guard let createdGeometry = geometry else { return nil }
        
        let pooledGeometry = PooledGeometry(
            geometry: createdGeometry,
            poolId: "\(poolName)-\(UUID().uuidString)"
        )
        
        // TODO: Stage 6 - Register with MemoryManager
        _ = memoryManager.registerGeometry(id: pooledGeometry.poolId, geometry: createdGeometry)
        
        return pooledGeometry
    }
    
    private func resetGeometry(_ geometry: SCNGeometry) {
        // Clear any custom materials or modifiers
        geometry.materials = []
        
        // Reset any custom shader modifiers
        for material in geometry.materials {
            material.shaderModifiers = [:]
        }
    }
    
    // MARK: - Statistics
    private func updateStatistics() {
        var newStatistics: [String: PoolStatistics] = [:]
        
        for (name, pool) in pools {
            let utilization = pool.totalCreated > 0 ? Double(pool.active) / Double(pool.totalCreated) : 0.0
            
            newStatistics[name] = PoolStatistics(
                available: pool.available.count,
                active: pool.active,
                totalCreated: pool.totalCreated,
                utilization: utilization
            )
        }
        
        poolStatistics = newStatistics
    }
    
    // MARK: - Pool Maintenance
    public func performMaintenance() {
        let now = Date()
        let maxIdleTime: TimeInterval = 300 // 5 minutes
        
        for (name, pool) in pools {
            // Remove excess idle geometries
            let idleGeometries = pool.available.filter { now.timeIntervalSince($0.lastUsed) > maxIdleTime }
            let excessCount = pool.available.count - 10 // Keep minimum of 10
            
            if excessCount > 0 {
                let toRemove = min(idleGeometries.count, excessCount)
                for _ in 0..<toRemove {
                    if !pool.available.isEmpty {
                        let removed = pool.available.removeLast()
                        // TODO: Stage 6 - Release from MemoryManager
                        memoryManager.releaseGeometry(id: removed.poolId)
                    }
                }
            }
        }
        
        updateStatistics()
        print("🔧 Pool maintenance completed")
    }
    
    // MARK: - Cleanup
    public func cleanup() {
        // Clear all pools
        pools.removeAll()
        activeGeometries.removeAll()
        poolStatistics.removeAll()
        
        print("🧹 Geometry pools cleaned up")
    }
}
