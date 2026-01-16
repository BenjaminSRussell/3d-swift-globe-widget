import Foundation
import Combine
import MapKit
import SwiftUI
import SceneKit

// TODO: Stage 6 - Add MemoryManager and PerformanceMonitor for performance optimization

/// Main ViewModel governing the application state
/// Enhanced for Stage 2: View mode management and morphing support
/// Stage 3: Network connectivity and data flow state management
/// TODO: Stage 6 - Integrate performance monitoring and memory management
@available(iOS 15.0, macOS 12.0, *)
@MainActor
public class GlobeViewModel: ObservableObject {
    
    // Dependencies
    public let themeManager = ThemeManager()
    private let networkService = NetworkService()
    private let graphicsEngine = GraphicsEngine()
    
    // Stage 3: Network Visualization Components
    private let networkTopologyRenderer: NetworkTopologyRenderer?
    private let dataFlowVisualizer: DataFlowVisualizer?
    private let networkInteraction: NetworkInteraction?
    private let bandwidthMonitor: BandwidthMonitor?
    
    // Stage 6: Performance Optimization Components
    private let memoryManager: MemoryManager
    private let performanceMonitor: PerformanceMonitor
    
    // State
    @Published public var nodes: [NetworkService.Node] = []
    @Published public var connections: [NetworkService.Connection] = []
    @Published public var cameraTarget: String? = nil
    @Published public var selectedNode: NetworkService.Node? = nil
    
    // Stage 2: View mode management
    public enum ViewMode {
        case globe3D, globe2D, hybrid
    }
    
    @Published public var viewMode: ViewMode = .globe3D
    @Published public var isMorphing: Bool = false
    @Published public var morphProgress: Float = 0.0
    
    // Stage 5: Camera System State
    @Published public var autoFitEnabled: Bool = true
    @Published public var smartFocusStrategy: FocusStrategy = .default
    
    // Stage 3: Performance Metrics
    @Published public var fps: Double = 60.0
    @Published public var memoryUsage: Double = 0.0 // In MB
    
    // TODO: Stage 6 - Enhanced performance monitoring
    @Published public var performanceScore: Double = 100.0
    @Published public var memoryPressure: String = "Normal"
    @Published public var activeResourceCount: Int = 0
    
    // Stage 6: Performance monitoring integration
    @Published public var showPerformanceOverlay: Bool = false
    @Published public var memoryStatistics: MemoryManager.MemoryStatistics = MemoryManager.MemoryStatistics(
        totalUsage: 0,
        categoryUsage: ["geometry": 0, "textures": 0, "shaders": 0, "particles": 0],
        pressureLevel: .normal
    )
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        // Initialize Stage 6 performance components
        self.memoryManager = MemoryManager()
        self.performanceMonitor = PerformanceMonitor()
        
        // Initialize Stage 3 network visualization components
        // Note: These would be initialized with actual scene references in a full implementation
        self.networkTopologyRenderer = nil // Would be initialized with SCNScene
        self.dataFlowVisualizer = nil // Would be initialized with SCNScene
        self.networkInteraction = nil // Would be initialized with SCNScene
        self.bandwidthMonitor = BandwidthMonitor(networkService: networkService, performanceMonitor: performanceMonitor)
        
        setupBindings()
        setupPerformanceMonitoring()
        networkService.loadData() // Initial data load
    }
    
    private func setupBindings() {
        // networkService is an ObservableObject, so we bind to its published properties
        networkService.$nodes
            .assign(to: \.nodes, on: self)
            .store(in: &cancellables)
            
        networkService.$connections
            .assign(to: \.connections, on: self)
            .store(in: &cancellables)
    }
    
    // Stage 6: Performance monitoring setup
    private func setupPerformanceMonitoring() {
        // Bind to performance monitor updates
        performanceMonitor.$frameRate
            .assign(to: \.fps, on: self)
            .store(in: &cancellables)
        
        performanceMonitor.$memoryUsage
            .assign(to: \.memoryUsage, on: self)
            .store(in: &cancellables)
        
        performanceMonitor.$performanceScore
            .assign(to: \.performanceScore, on: self)
            .store(in: &cancellables)
        
        // Bind to memory manager updates
        memoryManager.$totalMemoryUsage
            .map { Double($0) / (1024 * 1024) } // Convert to MB
            .assign(to: \.memoryUsage, on: self)
            .store(in: &cancellables)
        
        memoryManager.$memoryPressureLevel
            .map { pressureLevel in
                switch pressureLevel {
                case .normal: return "Normal"
                case .warning: return "Warning"
                case .critical: return "Critical"
                }
            }
            .assign(to: \.memoryPressure, on: self)
            .store(in: &cancellables)
        
        memoryManager.$currentUsage
            .map { $0.values.reduce(0, +) }
            .assign(to: \.activeResourceCount, on: self)
            .store(in: &cancellables)
        
        // Update memory statistics
        memoryManager.$currentUsage
            .combineLatest(memoryManager.$memoryPressureLevel, memoryManager.$totalMemoryUsage)
            .map { usage, pressure, total in
                MemoryManager.MemoryStatistics(
                    totalUsage: total,
                    categoryUsage: usage,
                    pressureLevel: pressure
                )
            }
            .assign(to: \.memoryStatistics, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Stage 5 Camera System Actions
    
    /// Auto-fits camera to display specified nodes with intelligent framing
    /// - Parameters:
    ///   - nodeIds: Array of node identifiers to fit in view
    ///   - completion: Optional completion handler
    public func autoFitCameraToNodes(_ nodeIds: [String], completion: (() -> Void)? = nil) {
        guard autoFitEnabled else { return }
        
        let appViewMode = convertToApplicationViewMode(viewMode)
        graphicsEngine.autoFitCameraToNodes(nodeIds, mode: appViewMode, completion: completion)
    }
    
    /// Smart focus using weighted algorithms
    /// - Parameters:
    ///   - nodeIds: Nodes to focus on
    ///   - strategy: Focus strategy (connection density, critical path, etc.)
    ///   - completion: Optional completion handler
    public func smartFocusCamera(_ nodeIds: [String], strategy: FocusStrategy? = nil, completion: (() -> Void)? = nil) {
        let focusStrategy = strategy ?? smartFocusStrategy
        graphicsEngine.smartFocusCamera(nodeIds, strategy: focusStrategy, completion: completion)
    }
    
    /// Updates camera system for performance optimization
    public func updateCameraSystem() {
        // TODO: Implement frame time tracking
        let deltaTime = 1.0 / 60.0 // Placeholder
        graphicsEngine.updateCameraSystem(deltaTime: deltaTime)
    }
    
    /// Invalidates cached camera bounds data
    public func invalidateCameraCache() {
        graphicsEngine.invalidateCameraCache()
    }
    
    /// Toggles auto-fit functionality
    public func toggleAutoFit() {
        autoFitEnabled.toggle()
    }
    
    /// Sets smart focus strategy
    /// - Parameter strategy: New focus strategy
    public func setSmartFocusStrategy(_ strategy: FocusStrategy) {
        smartFocusStrategy = strategy
    }
    
    // MARK: - Actions
    
    public func selectNode(_ id: String) {
        if let node = nodes.first(where: { $0.id == id }) {
            self.selectedNode = node
            self.cameraTarget = id
            print("GlobeViewModel: Selected \(id)")
            
            // Stage 5: Use auto-fit camera for node selection
            if autoFitEnabled {
                autoFitCameraToNodes([id]) {
                    print("GlobeViewModel: Auto-fit completed for node \(id)")
                }
            }
        }
    }
    
    public func clearSelection() {
        self.selectedNode = nil
        // Stage 5: Reset camera when clearing selection
        if autoFitEnabled {
            graphicsEngine.resetCamera()
        }
    }
    
    public func cycleTheme() {
        themeManager.toggleTheme()
    }
    
    // MARK: - Helper Methods
    
    private func convertToApplicationViewMode(_ mode: ViewMode) -> ApplicationState.ViewMode {
        switch mode {
        case .globe3D:
            return .globe3D
        case .globe2D:
            return .globe2D
        case .hybrid:
            return .hybrid
        }
    }
    
    // MARK: - Stage 2: View Mode Management
    
    /// Initiates morphing transition to specified view mode
    /// - Parameter mode: Target view mode
    public func morphToViewMode(_ mode: ViewMode) {
        guard viewMode != mode && !isMorphing else { return }
        
        isMorphing = true
        
        // TODO: Implement smooth morphing animation
        // TODO: Update morphProgress during animation
        // TODO: Handle camera transitions during morph
        
        // For now, immediate transition
        viewMode = mode
        updateMorphProgress(for: mode)
        isMorphing = false
    }
    
    /// Updates morph progress based on current view mode
    /// - Parameter mode: Current view mode
    private func updateMorphProgress(for mode: ViewMode) {
        switch mode {
        case .globe3D:
            morphProgress = 0.0
        case .globe2D:
            morphProgress = 1.0
        case .hybrid:
            morphProgress = 0.5
        }
    }
    
    /// Toggles between 3D and 2D view modes
    public func toggleViewMode() {
        let targetMode: ViewMode = (viewMode == .globe3D) ? .globe2D : .globe3D
        morphToViewMode(targetMode)
    }
    
    /// Gets coordinates for camera focusing based on selected nodes
    /// - Returns: Array of (latitude, longitude) tuples
    public func getSelectedNodeCoordinates() -> [(Double, Double)] {
        guard let selectedNode = selectedNode else {
            // Return all nodes if none selected
            return nodes.map { ($0.lat, $0.lon) }
        }
        
        // Return selected node and its connected nodes
        var coordinates = [(selectedNode.lat, selectedNode.lon)]
        
        let connectedNodeIds = connections
            .filter { $0.sourceId == selectedNode.id || $0.targetId == selectedNode.id }
            .map { $0.sourceId == selectedNode.id ? $0.targetId : $0.sourceId }
        
        for nodeId in connectedNodeIds {
            if let node = nodes.first(where: { $0.id == nodeId }) {
                coordinates.append((node.lat, node.lon))
            }
        }
        
        return coordinates
    }
    
    // MARK: - Stage 6 Performance Management
    
    /// Starts performance monitoring
    public func startPerformanceMonitoring() {
        performanceMonitor.start()
        bandwidthMonitor.startMonitoring()
    }
    
    /// Stops performance monitoring
    public func stopPerformanceMonitoring() {
        performanceMonitor.stop()
        bandwidthMonitor.stopMonitoring()
    }
    
    /// Toggles performance overlay visibility
    public func togglePerformanceOverlay() {
        showPerformanceOverlay.toggle()
    }
    
    /// Gets comprehensive performance report
    /// - Returns: Performance report with all metrics
    public func getPerformanceReport() -> PerformanceReport {
        return performanceMonitor.getPerformanceReport()
    }
    
    /// Gets bandwidth monitoring report
    /// - Returns: Bandwidth report with traffic analysis
    public func getBandwidthReport() -> BandwidthReport {
        return bandwidthMonitor.getBandwidthReport()
    }
    
    /// Performs memory cleanup
    public func performMemoryCleanup() {
        memoryManager.performCleanup()
    }
    
    /// Updates alert thresholds for performance monitoring
    /// - Parameters:
    ///   - memoryThreshold: Memory warning threshold in MB
    ///   - fpsThreshold: FPS warning threshold
    public func updatePerformanceThresholds(memoryThreshold: Double, fpsThreshold: Double) {
        // TODO: Update performance monitor thresholds
        // TODO: Update memory manager thresholds
        // TODO: Update bandwidth monitor thresholds
    }
    
    /// Analyzes system performance and returns recommendations
    /// - Returns: Performance recommendations
    public func analyzePerformance() -> PerformanceRecommendations {
        let report = getPerformanceReport()
        let bandwidthReport = getBandwidthReport()
        
        var recommendations: [String] = []
        
        // FPS recommendations
        if report.frameRate < 30 {
            recommendations.append("Consider reducing visual quality for better performance")
        } else if report.frameRate < 45 {
            recommendations.append("Performance is acceptable but could be optimized")
        }
        
        // Memory recommendations
        if report.memoryUsage > 500 {
            recommendations.append("High memory usage detected - consider cleanup")
        }
        
        // Bandwidth recommendations
        if bandwidthReport.utilization > 80 {
            recommendations.append("High network utilization - optimize data transfer")
        }
        
        return PerformanceRecommendations(
            overallScore: report.performanceScore,
            recommendations: recommendations,
            criticalIssues: report.recentAlerts.filter { $0.severity == .critical }.map { $0.message }
        )
    }
    
    // MARK: - Stage 3 Network Visualization Methods
    
    /// Triggers connection failure simulation
    /// - Parameters:
    ///   - nodeId: ID of node to simulate failure
    ///   - failureType: Type of failure to simulate
    public func triggerConnectionFailure(nodeId: String, failureType: FailureType) {
        networkTopologyRenderer?.triggerConnectionFailure(connectionId: nodeId, failureType: failureType)
        
        // TODO: Update node status in network service
        // TODO: Trigger particle effects
        // TODO: Log failure event
    }
    
    /// Triggers cascade failure simulation
    /// - Parameter nodeIds: Array of node IDs to fail in cascade
    public func triggerCascadeFailure(nodeIds: [String]) {
        for (index, nodeId) in nodeIds.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                self.triggerConnectionFailure(nodeId: nodeId, failureType: .connectionLost)
            }
        }
    }
    
    /// Updates data flow visualization
    /// - Parameters:
    ///   - connectionId: ID of connection
    ///   - bandwidth: Current bandwidth
    ///   - packetCount: Number of packets
    public func updateDataFlow(connectionId: String, bandwidth: Double, packetCount: Int) {
        let flowData = FlowData(bandwidth: bandwidth, packetCount: packetCount)
        dataFlowVisualizer?.updateFlow(for: connectionId, data: flowData)
        networkTopologyRenderer?.updateDataFlow(connectionId: connectionId, bandwidth: bandwidth, packetCount: packetCount)
    }
    
    /// Sets visualization mode for data flow
    /// - Parameter mode: Visualization mode
    public func setDataFlowVisualizationMode(_ mode: DataFlowVisualizer.VisualizationMode) {
        dataFlowVisualizer?.setVisualizationMode(mode)
    }
    
    /// Sets network interaction mode
    /// - Parameter mode: Interaction mode
    public func setNetworkInteractionMode(_ mode: NetworkInteraction.InteractionMode) {
        networkInteraction?.setInteractionMode(mode)
    }
}

// MARK: - Supporting Types

public struct PerformanceRecommendations {
    public let overallScore: Double
    public let recommendations: [String]
    public let criticalIssues: [String]
}
