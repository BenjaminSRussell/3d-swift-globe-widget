import Foundation
import SceneKit

/// Performance optimization components for camera system
/// Stage 5: Camera Systems - Caching and adaptive update mechanisms
@available(iOS 15.0, macOS 12.0, *)
public class BoundsCache {
    
    private var cache: [String: CachedBounds] = [:]
    private let cacheExpiry: TimeInterval = 5.0 // 5 seconds
    
    /// Retrieves cached bounds or calculates new ones
    /// - Parameter nodeIds: Array of node identifiers
    /// - Returns: Cached bounding sphere if valid
    public func getBounds(for nodeIds: [String]) -> (center: SCNVector3, radius: Float)? {
        let cacheKey = nodeIds.sorted().joined(separator: ",")
        
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiry {
            return cached.bounds
        }
        
        return nil
    }
    
    /// Stores bounds in cache
    /// - Parameters:
    ///   - bounds: Bounding sphere to cache
    ///   - nodeIds: Associated node identifiers
    public func setBounds(
        _ bounds: (center: SCNVector3, radius: Float),
        for nodeIds: [String]
    ) {
        let cacheKey = nodeIds.sorted().joined(separator: ",")
        cache[cacheKey] = CachedBounds(bounds: bounds, timestamp: Date())
    }
    
    /// Clears all cached bounds
    public func clear() {
        cache.removeAll()
    }
    
    /// Removes expired entries
    public func purgeExpired() {
        let now = Date()
        cache = cache.filter { Date().timeIntervalSince($0.value.timestamp) < cacheExpiry }
    }
}

private struct CachedBounds {
    let bounds: (center: SCNVector3, radius: Float)
    let timestamp: Date
}

/// Adaptive camera update system for performance optimization
/// Stage 5: Camera Systems - Dynamic update frequency based on performance
@available(iOS 15.0, macOS 12.0, *)
public class AdaptiveCameraUpdate {
    
    private var updateFrequency: Double = 60.0 // Start at 60 FPS
    private var performanceHistory: [TimeInterval] = []
    private let maxHistoryLength = 10
    private var frameCount = 0
    
    /// Records frame time for performance monitoring
    /// - Parameter frameTime: Time taken to render last frame
    public func recordFrameTime(_ frameTime: TimeInterval) {
        performanceHistory.append(frameTime)
        
        if performanceHistory.count > maxHistoryLength {
            performanceHistory.removeFirst()
        }
        
        adjustUpdateFrequency()
    }
    
    /// Determines if camera should update on current frame
    /// - Returns: True if update should occur
    public func shouldUpdate() -> Bool {
        frameCount += 1
        let updateInterval = Int(60.0 / updateFrequency)
        return frameCount % updateInterval == 0
    }
    
    /// Gets current update frequency
    /// - Returns: Current FPS target
    public func getCurrentFrequency() -> Double {
        return updateFrequency
    }
    
    private func adjustUpdateFrequency() {
        guard performanceHistory.count >= 3 else { return }
        
        let avgFrameTime = performanceHistory.reduce(0, +) / Double(performanceHistory.count)
        
        if avgFrameTime > 0.020 { // > 20ms = < 50 FPS
            updateFrequency = max(30.0, updateFrequency * 0.9)
        } else if avgFrameTime < 0.015 { // < 15ms = > 66 FPS
            updateFrequency = min(60.0, updateFrequency * 1.1)
        }
    }
}

/// Smart focus calculator for intelligent camera positioning
/// Stage 5: Camera Systems - Advanced focus algorithms
@available(iOS 15.0, macOS 12.0, *)
public class SmartFocusCalculator {
    
    private var focusWeights: [String: Float] = [:]
    
    /// Calculates weighted focus position based on strategy
    /// - Parameters:
    ///   - nodeIds: Array of node identifiers
    ///   - strategy: Focus strategy to use
    /// - Returns: Focus position and look-at point
    public func calculateWeightedFocus(
        nodeIds: [String],
        strategy: FocusStrategy
    ) -> (position: SCNVector3, lookAt: SCNVector3)? {
        
        switch strategy {
        case .default:
            return calculateDefaultFocus(nodeIds)
        case .connectionDensity:
            return calculateConnectionDensityFocus(nodeIds)
        case .criticalPath:
            return calculateCriticalPathFocus(nodeIds)
        case .weightedAverage:
            return calculateWeightedAverageFocus(nodeIds)
        }
    }
    
    /// Sets focus weight for specific node
    /// - Parameters:
    ///   - nodeId: Node identifier
    ///   - weight: Weight factor (higher = more important)
    public func setFocusWeight(for nodeId: String, weight: Float) {
        focusWeights[nodeId] = weight
    }
    
    // MARK: - Private Focus Strategies
    
    private func calculateDefaultFocus(_ nodeIds: [String]) -> (position: SCNVector3, lookAt: SCNVector3)? {
        // Get actual node positions from NetworkService
        let positions = nodeIds.compactMap { nodeId in
            if let node = networkService.nodes.first(where: { $0.id == nodeId }) {
                return Math.GeospatialMath.latLonToCartesian(lat: node.lat, lon: node.lon)
            }
            return nil
        }
        
        guard !positions.isEmpty else { return nil }
        
        let boundingSphere = BoundingCalculations.calculateBoundingSphere(positions)
        return (boundingSphere.center, boundingSphere.center)
    }
    
    private func calculateConnectionDensityFocus(_ nodeIds: [String]) -> (position: SCNVector3, lookAt: SCNVector3)? {
        // Group nodes by region and find highest density
        let regionCounts = calculateRegionDensity(nodeIds)
        
        guard let densestRegion = regionCounts.max(by: { $0.value < $1.value }) else {
            return calculateDefaultFocus(nodeIds)
        }
        
        // Calculate center of densest region
        let regionNodes = getNodesInRegion(nodeIds, region: densestRegion.key)
        return calculateDefaultFocus(regionNodes)
    }
    
    private func calculateCriticalPathFocus(_ nodeIds: [String]) -> (position: SCNVector3, lookAt: SCNVector3)? {
        // Network topology analysis to find critical nodes based on connection count
        let criticalNodes = nodeIds.filter { nodeId in
            let connectionCount = networkService.connections.filter { connection in
                connection.sourceId == nodeId || connection.targetId == nodeId
            }.count
            return connectionCount > 2 // Nodes with more than 2 connections are critical
        }
        
        if criticalNodes.isEmpty {
            return calculateDefaultFocus(nodeIds)
        }
        
        return calculateDefaultFocus(criticalNodes)
    }
    
    private func calculateWeightedAverageFocus(_ nodeIds: [String]) -> (position: SCNVector3, lookAt: SCNVector3)? {
        // Calculate weighted average based on focus weights
        var weightedPosition = SCNVector3Zero
        var totalWeight: Float = 0
        
        for nodeId in nodeIds {
            let weight = focusWeights[nodeId] ?? 1.0
            // Get actual node position
            if let node = networkService.nodes.first(where: { $0.id == nodeId }) {
                let position = Math.GeospatialMath.latLonToCartesian(lat: node.lat, lon: node.lon)
                weightedPosition = weightedPosition + position * weight
                totalWeight += weight
            }
        }
        
        guard totalWeight > 0 else { return nil }
        
        let centerPosition = weightedPosition / totalWeight
        return (centerPosition, centerPosition)
    }
    
    // MARK: - Helper Methods
    
    private func calculateRegionDensity(_ nodeIds: [String]) -> [String: Int] {
        var regionCounts: [String: Int] = [:]
        
        for nodeId in nodeIds {
            // Get actual node position
            if let node = networkService.nodes.first(where: { $0.id == nodeId }) {
                let position = Math.GeospatialMath.latLonToCartesian(lat: node.lat, lon: node.lon)
                let region = getRegion(for: position)
                regionCounts[region, default: 0] += 1
            }
        }
        
        return regionCounts
    }
    
    private func getRegion(for position: SCNVector3) -> String {
        // Geographic region classification based on lat/lon
        let lat = asin(position.y) * 180.0 / .pi
        let lon = atan2(position.z, position.x) * 180.0 / .pi
        
        // Classify by hemisphere and continent
        let hemisphere = lat >= 0 ? "N" : "S"
        let continent: String
        
        if lon >= -30 && lon <= 60 {
            continent = "EU" // Europe/Africa
        } else if lon >= -170 && lon <= -50 {
            continent = "AM" // Americas
        } else if lon >= 60 && lon <= 180 {
            continent = "AS" // Asia/Oceania
        } else {
            continent = "OT" // Other
        }
        
        return "\(hemisphere)\(continent)"
    }
    
    private func getNodesInRegion(_ nodeIds: [String], region: String) -> [String] {
        // Implement actual region-based node filtering
        return nodeIds.filter { nodeId in
            if let node = networkService.nodes.first(where: { $0.id == nodeId }) {
                let position = Math.GeospatialMath.latLonToCartesian(lat: node.lat, lon: node.lon)
                return getRegion(for: position) == region
            }
            return false
        }
    }
}

// MARK: - SCNVector3 Extensions

private extension SCNVector3 {
    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
    
    static func * (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        SCNVector3(lhs.x * CGFloat(rhs), lhs.y * CGFloat(rhs), lhs.z * CGFloat(rhs))
    }
    
    static func / (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        SCNVector3(lhs.x / CGFloat(rhs), lhs.y / CGFloat(rhs), lhs.z / CGFloat(rhs))
    }
}
