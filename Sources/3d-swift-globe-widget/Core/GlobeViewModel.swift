import Foundation
import Combine
import MapKit
import SwiftUI

// TODO: Stage 3 - Add NetworkTopologyRenderer instance for connectivity management
// TODO: Stage 3 - Add DataFlowVisualizer instance for packet simulation
// TODO: Stage 3 - Add NetworkInteraction instance for user interaction
// TODO: Stage 3 - Add BandwidthMonitor instance for traffic monitoring
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
    
    // Stage 3: Performance Metrics
    @Published public var fps: Double = 60.0
    @Published public var memoryUsage: Double = 0.0 // In MB
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupBindings()
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
    
    // MARK: - Actions
    
    public func selectNode(_ id: String) {
        if let node = nodes.first(where: { $0.id == id }) {
            self.selectedNode = node
            self.cameraTarget = id
            print("GlobeViewModel: Selected \(id)")
        }
    }
    
    public func clearSelection() {
        self.selectedNode = nil
    }
    
    public func cycleTheme() {
        themeManager.toggleTheme()
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
}
