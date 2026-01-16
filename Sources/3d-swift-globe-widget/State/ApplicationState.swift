import Foundation
import Combine
import SwiftUI
import QuartzCore

/// Centralized state management for the 3D visualization
/// Enhanced for Phase 2: Advanced Globe Morphing and State Management
/// STAGE 7 TODO: Integrate high-frequency state management system for 60 FPS updates
/// STAGE 7 TODO: Add frequency-based state separation (realtime, animation, simulation, UI, data)
@available(iOS 15.0, macOS 12.0, *)
public class ApplicationState: ObservableObject {
    
    public enum ViewMode: CaseIterable {
        case globe3D
        case globe2D
        case hybrid
        case map2D
        
        var displayName: String {
            switch self {
            case .globe3D: return "3D Globe"
            case .globe2D: return "2D Globe"
            case .hybrid: return "Hybrid"
            case .map2D: return "2D Map"
            }
        }
        
        var mixFactor: Float {
            switch self {
            case .globe3D: return 0.0
            case .globe2D: return 1.0
            case .hybrid: return 0.5
            case .map2D: return 1.0
            }
        }
    }
    
    @Published public var viewMode: ViewMode = .globe3D
    @Published public var mixFactor: Float = 0.0 // 0.0 = 3D, 1.0 = 2D
    @Published public var selectedNodeId: String? = nil
    @Published public var isAutoRotating: Bool = true
    @Published public var morphProgress: Float = 0.0
    @Published public var isTransitioning: Bool = false
    
    // STAGE 7 TODO: Add high-frequency state properties (particle positions, camera, animation)
    // STAGE 7 TODO: Implement separate state containers for different update frequencies
    // STAGE 7 TODO: Add Float32Array buffers for particle system state
    
    // Advanced morphing properties
    @Published public var morphDuration: TimeInterval = 2.0
    @Published public var morphEasing: MorphEasing = .easeInOut
    @Published public var autoMorphEnabled: Bool = false
    
    public enum MorphEasing: CaseIterable {
        case linear
        case easeIn
        case easeOut
        case easeInOut
        case spring
        
        var timingFunction: CAMediaTimingFunctionName {
            switch self {
            case .linear: return .linear
            case .easeIn: return .easeIn
            case .easeOut: return .easeOut
            case .easeInOut: return .easeInEaseOut
            case .spring: return .default
            }
        }
    }
    
    public init() {}
    
    // STAGE 7 TODO: Initialize high-frequency state containers
    // STAGE 7 TODO: Setup frequency-based update loops
    // STAGE 7 TODO: Create batched update system
    
    // MARK: - View Mode Transitions
    
    /// Cycles through available view modes
    public func cycleViewMode() {
        let allModes: [ViewMode] = [.globe3D, .globe2D, .hybrid, .map2D]
        guard let currentIndex = allModes.firstIndex(of: viewMode) else { return }
        let nextIndex = (currentIndex + 1) % allModes.count
        transitionTo(allModes[nextIndex])
    }
    
    /// Transitions to a specific view mode with animation
    public func transitionTo(_ target: ViewMode, animated: Bool = true) {
        guard animated else {
            viewMode = target
            mixFactor = target.mixFactor
            return
        }
        
        isTransitioning = true
        
        // Animate the transition
        withAnimation(.easeInOut(duration: morphDuration)) {
            viewMode = target
            mixFactor = target.mixFactor
        }
        
        // Complete transition after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + morphDuration) {
            self.isTransitioning = false
            self.morphProgress = 1.0
        }
    }
    
    /// Toggles between 3D and 2D views (legacy support)
    public func toggleViewMode() {
        let target: ViewMode = (viewMode == .globe3D) ? .globe2D : .globe3D
        transitionTo(target)
    }
    
    /// Initiates auto-morphing cycle
    public func startAutoMorphing() {
        autoMorphEnabled = true
        // Auto-morphing logic would be handled by timer in GraphicsEngine
    }
    
    /// Stops auto-morphing cycle
    public func stopAutoMorphing() {
        autoMorphEnabled = false
    }
    
    /// Updates morph progress during animation
    public func updateMorphProgress(_ progress: Float) {
        morphProgress = progress
        mixFactor = progress
    }
    
    // MARK: - Selection Management
    
    /// Selects a node by ID with animation
    public func selectNode(_ nodeId: String, animated: Bool = true) {
        if animated {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                selectedNodeId = nodeId
            }
        } else {
            selectedNodeId = nodeId
        }
    }
    
    /// Clears current selection
    public func clearSelection() {
        withAnimation(.easeOut(duration: 0.3)) {
            selectedNodeId = nil
        }
    }
    
    // MARK: - Animation Settings
    
    /// Updates morph animation duration
    public func setMorphDuration(_ duration: TimeInterval) {
        morphDuration = max(0.5, min(5.0, duration))
    }
    
    /// Updates morph easing function
    public func setMorphEasing(_ easing: MorphEasing) {
        morphEasing = easing
    }
    
    // MARK: - State Reset
    
    /// Resets all state to defaults
    public func resetToDefaults() {
        withAnimation(.easeInOut(duration: 1.0)) {
            viewMode = .globe3D
            mixFactor = 0.0
            selectedNodeId = nil
            isAutoRotating = true
            morphProgress = 0.0
            isTransitioning = false
            autoMorphEnabled = false
        }
    }
    
    // MARK: - STAGE 7: High-Frequency State Management
    
    // TODO: Add updateParticle(index:position:velocity:life:) method for 60 FPS updates
    // TODO: Add updateCamera(position:target:) method with update flags
    // TODO: Add updateAnimation(time:deltaTime:frameCount:) method
    // TODO: Add frequency-based subscription system
    // TODO: Add batched update processing methods
    // TODO: Add memory-efficient state buffer management
}
