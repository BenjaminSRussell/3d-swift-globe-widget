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
        private var lastSplitCheck: TimeInterval = 0
        private let splitCheckInterval: TimeInterval = 1.0 // Check every second
        
        // Dynamic splitting based on particle density
        private var particleDensityThreshold: Float = 10.0 // particles per unit volume
        private var mergeThreshold: Int = 5 // minimum particles to prevent merging
        
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
        
        /// Checks and performs dynamic splitting based on particle density
        func updateDynamicSplitting(currentTime: TimeInterval) {
            guard currentTime - lastSplitCheck > splitCheckInterval else { return }
            lastSplitCheck = currentTime
            
            let volume = bounds.volume()
            let density = Float(particles.count) / volume
            
            // Split if density exceeds threshold and we haven't reached max depth
            if isLeaf && density > particleDensityThreshold && depth < maxDepth {
                split()
            }
            
            // Merge children if they have few particles
            if !isLeaf && shouldMerge() {
                merge()
            }
        }
        
        /// Determines if node should be merged based on particle count in children
        private func shouldMerge() -> Bool {
            let totalParticles = children.compactMap { $0?.particles.count }.reduce(0, +)
            return totalParticles < mergeThreshold && depth > 0
        }
        
        /// Merges children back into this node
        private func merge() {
            var allParticles: [ParticleReference] = []
            
            for child in children {
                if let child = child {
                    allParticles.append(contentsOf: child.particles)
                }
            }
            
            children = Array(repeating: nil, count: 8)
            particles = allParticles
            isLeaf = true
        }
        
        /// Queries particles within a frustum
        func queryInFrustum(_ frustum: Frustum) -> [ParticleReference] {
            var results: [ParticleReference] = []
            
            // Efficient frustum-AABB intersection with early-out optimization
            let (intersects, distance) = efficientFrustumIntersection(frustum)
            
            if intersects {
                if isLeaf {
                    results.append(contentsOf: particles)
                } else {
                    // Sort children by distance for better culling
                    let sortedChildren = children.compactMap { $0 }
                        .sorted { child1, child2 in
                            let dist1 = simd_length(
                                simd_float3(child1.bounds.center().x, child1.bounds.center().y, child1.bounds.center().z) -
                                simd_float3(frustum.position.x, frustum.position.y, frustum.position.z)
                            )
                            let dist2 = simd_length(
                                simd_float3(child2.bounds.center().x, child2.bounds.center().y, child2.bounds.center().z) -
                                simd_float3(frustum.position.x, frustum.position.y, frustum.position.z)
                            )
                            return dist1 < dist2
                        }
                    
                    for child in sortedChildren {
                        results.append(contentsOf: child.queryInFrustum(frustum))
                    }
                }
            }
            
            return results
        }
        
        /// Efficient frustum-AABB intersection with early-out optimization
        private func efficientFrustumIntersection(_ frustum: Frustum) -> (intersects: Bool, distance: Float) {
            // Calculate distance from frustum center to bounds center
            let boundsCenter = bounds.center()
            let frustumCenter = frustum.position
            let distance = simd_length(
                simd_float3(boundsCenter.x, boundsCenter.y, boundsCenter.z) - 
                simd_float3(frustumCenter.x, frustumCenter.y, frustumCenter.z)
            )
            
            // Early-out for distant nodes
            if distance > frustum.farPlane * 2.0 {
                return (false, distance)
            }
            
            // Perform actual intersection test
            let intersects = bounds.intersectsFrustum(frustum)
            return (intersects, distance)
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
        
        // Dynamic grid resizing and optimization
        private var lastResizeCheck: TimeInterval = 0
        private let resizeCheckInterval: TimeInterval = 2.0
        private var particleCountThreshold: Int = 1000
        private var utilizationThreshold: Float = 0.8
        
        // Hash-based grid for sparse data optimization
        private var useHashGrid: Bool = false
        private var hashGrid: [Int: [ParticleReference]] = [:]
        private let hashGridSize: Int = 1024
        
        // Neighbor finding cache
        private var neighborCache: [Int: [Int]] = [:]
        
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
        
        /// Updates grid with dynamic resizing and optimization
        func updateWithDynamicResizing(currentTime: TimeInterval) {
            guard currentTime - lastResizeCheck > resizeCheckInterval else { return }
            lastResizeCheck = currentTime
            
            let totalParticles = grid.reduce(0) { $0 + $1.count }
            let totalCells = gridSize * gridSize * gridSize
            let utilization = Float(totalParticles) / Float(totalCells)
            
            // Switch to hash grid if utilization is low (sparse data)
            if utilization < 0.1 && !useHashGrid {
                convertToHashGrid()
            }
            // Switch back to regular grid if utilization is high
            else if utilization > 0.5 && useHashGrid {
                convertToRegularGrid()
            }
            
            // Resize grid if particle count exceeds threshold
            if totalParticles > particleCountThreshold && gridSize < 200 {
                resizeGrid(newSize: gridSize * 2)
            }
        }
        
        /// Converts to hash-based grid for sparse data
        private func convertToHashGrid() {
            useHashGrid = true
            hashGrid.removeAll()
            
            for (index, cell) in grid.enumerated() {
                if !cell.isEmpty {
                    hashGrid[index] = cell
                }
            }
            
            // Clear regular grid to save memory
            grid.removeAll()
        }
        
        /// Converts back to regular grid for dense data
        private func convertToRegularGrid() {
            useHashGrid = false
            
            // Reinitialize regular grid
            let totalCells = gridSize * gridSize * gridSize
            grid = Array(repeating: [], count: totalCells)
            
            // Transfer particles from hash grid
            for (index, particles) in hashGrid {
                if index < grid.count {
                    grid[index] = particles
                }
            }
            
            hashGrid.removeAll()
        }
        
        /// Resizes the grid to a new size
        private func resizeGrid(newSize: Int) {
            let oldGrid = grid
            let oldSize = gridSize
            
            // Create new grid
            let totalCells = newSize * newSize * newSize
            grid = Array(repeating: [], count: totalCells)
            
            // Reinsert all particles with new grid coordinates
            for cell in oldGrid {
                for particle in cell {
                    insert(particle)
                }
            }
        }
        
        /// Finds neighboring particles for interactions
        func findNeighbors(for particle: ParticleReference, radius: Float) -> [ParticleReference] {
            let gridPos = worldToGrid(particle.position)
            let hashKey = hashKey(for: gridPos)
            
            // Check cache first
            if let cachedNeighbors = neighborCache[hashKey] {
                return cachedNeighbors.compactMap { index in
                    if index < grid.count {
                        return grid[index].first { $0.id != particle.id }
                    }
                    return nil
                }
            }
            
            // Calculate neighbor cells within radius
            let cellRadius = Int(ceil(radius / cellSize))
            var neighbors: [ParticleReference] = []
            
            for dx in -cellRadius...cellRadius {
                for dy in -cellRadius...cellRadius {
                    for dz in -cellRadius...cellRadius {
                        let neighborPos = (
                            x: gridPos.x + dx,
                            y: gridPos.y + dy,
                            z: gridPos.z + dz
                        )
                        
                        if isValidGridPosition(neighborPos) {
                            let index = gridIndex(for: neighborPos)
                            if index < grid.count {
                                neighbors.append(contentsOf: grid[index])
                            }
                        }
                    }
                }
            }
            
            // Cache the result
            neighborCache[hashKey] = neighbors.map { $0.id.hashValue }
            
            return neighbors.filter { $0.id != particle.id }
        }
        
        /// Generates hash key for grid position
        private func hashKey(for pos: (x: Int, y: Int, z: Int)) -> Int {
            return (pos.x * 73856093) ^ (pos.y * 19349663) ^ (pos.z * 83492791) % hashGridSize
        }
        
        /// Validates grid position
        private func isValidGridPosition(_ pos: (x: Int, y: Int, z: Int)) -> Bool {
            return pos.x >= 0 && pos.x < gridSize &&
                   pos.y >= 0 && pos.y < gridSize &&
                   pos.z >= 0 && pos.z < gridSize
        }
        
        /// Converts grid position to array index
        private func gridIndex(for pos: (x: Int, y: Int, z: Int)) -> Int {
            return pos.x + pos.y * gridSize + pos.z * gridSize * gridSize
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
        
        func volume() -> Float {
            let size = self.size
            return size.x * size.y * size.z
        }
        
        func intersectsFrustum(_ frustum: Frustum) -> Bool {
            // Efficient AABB-frustum intersection using separating axis theorem
            let center = self.center
            let halfExtents = SCNVector3(
                (max.x - min.x) * 0.5,
                (max.y - min.y) * 0.5,
                (max.z - min.z) * 0.5
            )
            
            // Test against each frustum plane
            // For simplicity, we'll use a simplified approach with far plane and distance check
            // In a full implementation, you'd test against all 6 frustum planes
            
            let centerDist = simd_length(
                simd_float3(center.x, center.y, center.z) - frustum.position
            )
            let maxRadius = simd_length(
                simd_float3(halfExtents.x, halfExtents.y, halfExtents.z)
            )
            
            // Quick distance-based culling
            if centerDist > frustum.farPlane + maxRadius {
                return false
            }
            
            // More precise intersection test would go here
            // For now, this provides reasonable culling performance
            return true
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
