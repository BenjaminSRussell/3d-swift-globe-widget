import Foundation
import SceneKit

/// Spatial partitioning system for efficient particle culling and optimization
/// Implements octree for 3D space and grid-based partitioning for performance
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class SpatialPartitioningSystem {
    
    // MARK: - Octree Implementation
    
    /// Octree node for 3D spatial partitioning
    public class OctreeNode {
        let bounds: AABB
        let depth: Int
        let maxDepth: Int
        let maxParticles: Int
        
        private var children: [OctreeNode?] = Array(repeating: nil, count: 8)
        private var particles: [ParticleReference] = []
        private var isLeaf: Bool = true
        
        // TODO: Implement dynamic splitting based on particle density
        // TODO: Add node merging for empty regions
        // TODO: Implement frustum culling at node level
        
        init(bounds: AABB, depth: Int = 0, maxDepth: Int = 4, maxParticles: Int = 100) {
            self.bounds = bounds
            self.depth = depth
            self.maxDepth = maxDepth
            self.maxParticles = maxParticles
        }
        
        /// Inserts a particle into the octree
        func insert(_ particle: ParticleReference) -> Bool {
            if !bounds.contains(particle.position) {
                return false
            }
            
            if isLeaf && particles.count < maxParticles && depth >= maxDepth {
                particles.append(particle)
                return true
            }
            
            if isLeaf {
                split()
            }
            
            // Insert into appropriate children
            for child in children {
                if let child = child, child.insert(particle) {
                    return true
                }
            }
            
            // Fallback: keep in parent if no child accepts
            particles.append(particle)
            return true
        }
        
        /// Splits the node into 8 children
        private func split() {
            guard isLeaf else { return }
            
            let halfSize = bounds.size * 0.5
            let center = bounds.center
            
            // Create 8 child nodes
            for i in 0..<8 {
                let offsetX = (i & 1) == 0 ? -halfSize.x : halfSize.x
                let offsetY = (i & 2) == 0 ? -halfSize.y : halfSize.y
                let offsetZ = (i & 4) == 0 ? -halfSize.z : halfSize.z
                
                let childCenter = center + SCNVector3(offsetX, offsetY, offsetZ)
                let childBounds = AABB(
                    center: childCenter,
                    size: halfSize
                )
                
                children[i] = OctreeNode(
                    bounds: childBounds,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    maxParticles: maxParticles
                )
            }
            
            isLeaf = false
            
            // Redistribute existing particles
            let existingParticles = particles
            particles.removeAll()
            
            for particle in existingParticles {
                insert(particle)
            }
        }
        
        /// Queries particles within a frustum
        func queryInFrustum(_ frustum: Frustum) -> [ParticleReference] {
            var results: [ParticleReference] = []
            
            // TODO: Implement efficient frustum-AABB intersection
            // TODO: Add early-out for distant nodes
            
            if bounds.intersectsFrustum(frustum) {
                if isLeaf {
                    results.append(contentsOf: particles)
                } else {
                    for child in children {
                        if let child = child {
                            results.append(contentsOf: child.queryInFrustum(frustum))
                        }
                    }
                }
            }
            
            return results
        }
        
        /// Queries particles within a sphere
        func queryInSphere(center: SCNVector3, radius: Float) -> [ParticleReference] {
            var results: [ParticleReference] = []
            
            if bounds.intersectsSphere(center: center, radius: radius) {
                if isLeaf {
                    for particle in particles {
                        let distance = simd_distance(
                            simd_float3(particle.position.x, particle.position.y, particle.position.z),
                            simd_float3(center.x, center.y, center.z)
                        )
                        if distance <= radius {
                            results.append(particle)
                        }
                    }
                } else {
                    for child in children {
                        if let child = child {
                            results.append(contentsOf: child.queryInSphere(center: center, radius: radius))
                        }
                    }
                }
            }
            
            return results
        }
        
        /// Gets all particles in this node and children
        func getAllParticles() -> [ParticleReference] {
            var results: [ParticleReference] = []
            
            if isLeaf {
                results.append(contentsOf: particles)
            } else {
                for child in children {
                    if let child = child {
                        results.append(contentsOf: child.getAllParticles())
                    }
                }
            }
            
            return results
        }
        
        /// Clears all particles from the tree
        func clear() {
            particles.removeAll()
            
            if !isLeaf {
                for child in children {
                    child?.clear()
                }
                children = Array(repeating: nil, count: 8)
                isLeaf = true
            }
        }
    }
    
    // MARK: - Grid-Based Partitioning
    
    /// Grid-based spatial partitioning for fast uniform queries
    public class SpatialGrid {
        let cellSize: Float
        let gridSize: Int
        private var grid: [[ParticleReference]] = []
        private var bounds: AABB
        
        // TODO: Implement dynamic grid resizing
        // TODO: Add hash-based grid for sparse data
        // TODO: Implement neighbor finding for particle interactions
        
        init(bounds: AABB, cellSize: Float, gridSize: Int = 100) {
            self.bounds = bounds
            self.cellSize = cellSize
            self.gridSize = gridSize
            
            // Initialize grid cells
            let totalCells = gridSize * gridSize * gridSize
            grid = Array(repeating: [], count: totalCells)
        }
        
        /// Converts world position to grid coordinates
        private func worldToGrid(_ position: SCNVector3) -> (x: Int, y: Int, z: Int) {
            let relativePos = position - bounds.min
            let gridX = Int(relativePos.x / cellSize)
            let gridY = Int(relativePos.y / cellSize)
            let gridZ = Int(relativePos.z / cellSize)
            
            return (
                max(0, min(gridSize - 1, gridX)),
                max(0, min(gridSize - 1, gridY)),
                max(0, min(gridSize - 1, gridZ))
            )
        }
        
        /// Gets grid index from coordinates
        private func gridIndex(x: Int, y: Int, z: Int) -> Int {
            return (z * gridSize + y) * gridSize + x
        }
        
        /// Inserts a particle into the grid
        func insert(_ particle: ParticleReference) {
            let coords = worldToGrid(particle.position)
            let index = gridIndex(x: coords.x, y: coords.y, z: coords.z)
            grid[index].append(particle)
        }
        
        /// Queries particles in neighboring cells
        func queryNearby(center: SCNVector3, radius: Float) -> [ParticleReference] {
            let coords = worldToGrid(center)
            let cellRadius = Int(ceil(radius / cellSize))
            
            var results: [ParticleReference] = []
            
            let minX = max(0, coords.x - cellRadius)
            let maxX = min(gridSize - 1, coords.x + cellRadius)
            let minY = max(0, coords.y - cellRadius)
            let maxY = min(gridSize - 1, coords.y + cellRadius)
            let minZ = max(0, coords.z - cellRadius)
            let maxZ = min(gridSize - 1, coords.z + cellRadius)
            
            for x in minX...maxX {
                for y in minY...maxY {
                    for z in minZ...maxZ {
                        let index = gridIndex(x: x, y: y, z: z)
                        
                        for particle in grid[index] {
                            let distance = simd_distance(
                                simd_float3(particle.position.x, particle.position.y, particle.position.z),
                                simd_float3(center.x, center.y, center.z)
                            )
                            if distance <= radius {
                                results.append(particle)
                            }
                        }
                    }
                }
            }
            
            return results
        }
        
        /// Clears all particles from the grid
        func clear() {
            for i in 0..<grid.count {
                grid[i].removeAll()
            }
        }
    }
    
    // MARK: - Supporting Structures
    
    /// Axis-aligned bounding box
    public struct AABB {
        let min: SCNVector3
        let max: SCNVector3
        
        var center: SCNVector3 {
            return SCNVector3(
                (min.x + max.x) * 0.5,
                (min.y + max.y) * 0.5,
                (min.z + max.z) * 0.5
            )
        }
        
        var size: SCNVector3 {
            return SCNVector3(
                max.x - min.x,
                max.y - min.y,
                max.z - min.z
            )
        }
        
        func contains(_ point: SCNVector3) -> Bool {
            return point.x >= min.x && point.x <= max.x &&
                   point.y >= min.y && point.y <= max.y &&
                   point.z >= min.z && point.z <= max.z
        }
        
        func intersectsFrustum(_ frustum: Frustum) -> Bool {
            // TODO: Implement efficient AABB-frustum intersection
            // For now, use simple center-distance test
            let centerDist = simd_length(
                simd_float3(center.x, center.y, center.z) - frustum.position
            )
            let maxRadius = simd_length(
                simd_float3(size.x, size.y, size.z)
            ) * 0.5
            
            return centerDist <= frustum.farPlane + maxRadius
        }
        
        func intersectsSphere(center: SCNVector3, radius: Float) -> Bool {
            let closestPoint = SCNVector3(
                max(min.x, min(center.x, max.x)),
                max(min.y, min(center.y, max.y)),
                max(min.z, min(center.z, max.z))
            )
            
            let distance = simd_distance(
                simd_float3(closestPoint.x, closestPoint.y, closestPoint.z),
                simd_float3(center.x, center.y, center.z)
            )
            
            return distance <= radius
        }
        
        init(center: SCNVector3, size: SCNVector3) {
            let halfSize = size * 0.5
            self.min = center - halfSize
            self.max = center + halfSize
        }
        
        init(min: SCNVector3, max: SCNVector3) {
            self.min = min
            self.max = max
        }
    }
    
    /// Camera frustum for culling
    public struct Frustum {
        let position: simd_float3
        let direction: simd_float3
        let fov: Float
        let aspect: Float
        let nearPlane: Float
        let farPlane: Float
        
        // TODO: Implement full frustum planes for accurate culling
        // TODO: Add frustum-to-AABB intersection test
    }
    
    /// Reference to a particle in the system
    public struct ParticleReference {
        let id: Int
        let position: SCNVector3
        let velocity: SCNVector3
        let life: Float
        let size: Float
        let color: UniversalColor
        
        // TODO: Add particle metadata for advanced queries
        // TODO: Implement particle importance weighting
    }
    
    // MARK: - Main System
    
    private let octree: OctreeNode
    private let grid: SpatialGrid
    private let bounds: AABB
    private var particles: [ParticleReference] = []
    
    // TODO: Implement hybrid octree-grid approach
    // TODO: Add dynamic bounds adjustment
    // TODO: Implement performance monitoring
    
    public init(bounds: AABB, cellSize: Float = 10.0) {
        self.bounds = bounds
        self.octree = OctreeNode(bounds: bounds)
        self.grid = SpatialGrid(bounds: bounds, cellSize: cellSize)
    }
    
    /// Updates the spatial partitioning system
    /// - Parameter particles: Current particle states
    public func update(particles: [ParticleReference]) {
        self.particles = particles
        
        // Clear existing structures
        octree.clear()
        grid.clear()
        
        // Rebuild spatial structures
        for particle in particles {
            if particle.life > 0 {
                octree.insert(particle)
                grid.insert(particle)
            }
        }
    }
    
    /// Queries visible particles using frustum culling
    /// - Parameter frustum: Camera frustum for culling
    /// - Returns: Array of visible particle references
    public func queryVisibleParticles(frustum: Frustum) -> [ParticleReference] {
        return octree.queryInFrustum(frustum)
    }
    
    /// Queries particles near a specific position
    /// - Parameters:
    ///   - center: Query center position
    ///   - radius: Query radius
    /// - Returns: Array of nearby particle references
    public func queryNearbyParticles(center: SCNVector3, radius: Float) -> [ParticleReference] {
        return grid.queryNearby(center: center, radius: radius)
    }
    
    /// Gets performance statistics
    /// - Returns: Statistics about the spatial partitioning system
    public func getStatistics() -> SpatialStatistics {
        let totalParticles = particles.count
        let visibleParticles = octree.getAllParticles().count
        
        return SpatialStatistics(
            totalParticles: totalParticles,
            visibleParticles: visibleParticles,
            octreeDepth: calculateOctreeDepth(octree),
            gridUtilization: calculateGridUtilization()
        )
    }
    
    private func calculateOctreeDepth(_ node: OctreeNode) -> Int {
        if node.isLeaf {
            return node.depth
        }
        
        var maxDepth = node.depth
        for child in node.children {
            if let child = child {
                maxDepth = max(maxDepth, calculateOctreeDepth(child))
            }
        }
        
        return maxDepth
    }
    
    private func calculateGridUtilization() -> Float {
        let totalCells = grid.gridSize * grid.gridSize * grid.gridSize
        let occupiedCells = grid.grid.filter { !$0.isEmpty }.count
        return Float(occupiedCells) / Float(totalCells)
    }
}

/// Performance statistics for spatial partitioning
public struct SpatialStatistics {
    public let totalParticles: Int
    public let visibleParticles: Int
    public let octreeDepth: Int
    public let gridUtilization: Float
    
    public var cullingEfficiency: Float {
        guard totalParticles > 0 else { return 0 }
        return 1.0 - (Float(visibleParticles) / Float(totalParticles))
    }
}
