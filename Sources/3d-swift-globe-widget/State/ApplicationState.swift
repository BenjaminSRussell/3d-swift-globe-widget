import Foundation
import Combine

/// Centralized state management for the 3D visualization
@available(iOS 15.0, macOS 12.0, *)
public class ApplicationState: ObservableObject {
    
    public enum ViewMode {
        case globe3D
        case map2D
    }
    
    @Published public var viewMode: ViewMode = .globe3D
    @Published public var mixFactor: Float = 0.0 // 0.0 = 3D, 1.0 = 2D
    @Published public var selectedNodeId: String? = nil
    @Published public var isAutoRotating: Bool = true
    
    public init() {}
    
    /// Transitions between 3D and 2D views
    public func toggleViewMode() {
        let target: ViewMode = (viewMode == .globe3D) ? .map2D : .globe3D
        transitionTo(target)
    }
    
    private func transitionTo(_ target: ViewMode) {
        // Animation logic would be handled by a controller or engine
        viewMode = target
    }
}
