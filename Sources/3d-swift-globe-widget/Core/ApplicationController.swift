import Foundation
import Combine
import SceneKit

/// The main controller that orchestrates the data flow and rendering engine.
/// Strictly follows Phase 6 architecture refinements.
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class ApplicationController: ObservableObject {
    
    @Published public var engine: GraphicsEngine
    @Published public var networkService: NetworkService
    @Published public var state: ApplicationState
    
    private var cancellables = Set<AnyCancellable>()
    
    public init(engine: GraphicsEngine, networkService: NetworkService, state: ApplicationState) {
        self.engine = engine
        self.networkService = networkService
        self.state = state
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind network data to graphics engine
        networkService.$connections
            .sink { [weak self] connections in
                self?.engine.updateArcs(for: connections)
            }
            .store(in: &cancellables)
            
        // Future: Bind node status changes to visual states
    }
    
    /// Simulates a network failure event at a specific node
    public func simulateFailure(at nodeId: String) {
        guard let node = networkService.nodes.first(where: { $0.id == nodeId }) else { return }
        
        // 1. Update state
        state.selectedNodeId = nodeId
        
        // 2. Trigger visual burst
        let position = GeospatialMath.latLonToCartesian(lat: node.lat, lon: node.lon)
        engine.triggerBurst(at: position, color: .red) // Failure red
        
        // 3. Dynamic Camera Focus
        engine.focusCamera(on: node)
        
        // Auto-reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.engine.resetCamera()
        }
        
        print("ApplicationController: Simulated failure at \(nodeId)")
    }
    
    public func start() {
        networkService.loadData()
    }
}
