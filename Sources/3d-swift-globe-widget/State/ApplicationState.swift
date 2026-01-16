import Foundation
import Combine
import SwiftUI
import QuartzCore
import simd

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
    
    // MARK: - Low-Frequency Published Properties (UI Updates)
    
    @Published public var viewMode: ViewMode = .globe3D
    @Published public var mixFactor: Float = 0.0 // 0.0 = 3D, 1.0 = 2D
    @Published public var selectedNodeId: String? = nil
    @Published public var isAutoRotating: Bool = true
    @Published public var morphProgress: Float = 0.0
    @Published public var isTransitioning: Bool = false
    
    // Stage 7: High-frequency state manager integration
    public let highFrequencyManager: HighFrequencyStateManager
    
    // Advanced morphing properties
    @Published public var morphDuration: TimeInterval = 2.0
    @Published public var morphEasing: MorphEasing = .easeInOut
    @Published public var autoMorphEnabled: Bool = false
    
    // Performance monitoring from high-frequency manager
    @Published public var currentFPS: Double = 60.0
    @Published public var isPerformanceOptimal: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    
    public enum MorphEasing: CaseIterable {
        case linear
        case easeIn
        case easeOut
        case easeInOut
        case spring
        
        var timingFunction: String {
            switch self {
            case .linear: return CAMediaTimingFunctionName.linear.rawValue
            case .easeIn: return CAMediaTimingFunctionName.easeIn.rawValue
            case .easeOut: return CAMediaTimingFunctionName.easeOut.rawValue
            case .easeInOut: return CAMediaTimingFunctionName.easeInEaseOut.rawValue
            case .spring: return CAMediaTimingFunctionName.default.rawValue
            }
        }
    }
    
    public init(maxParticles: Int = 100_000) {
        // STAGE 7: Initialize high-frequency state containers
        // STAGE 7: Setup frequency-based update loops
        // STAGE 7: Create batched update system
        self.highFrequencyManager = HighFrequencyStateManager(maxParticles: maxParticles)
        
        setupPerformanceMonitoring()
        startHighFrequencyUpdates()
    }

    // MARK: - Performance Monitoring Setup
    
    private func setupPerformanceMonitoring() {
        // Monitor performance from high-frequency manager
        highFrequencyManager.$isPerformanceOptimal
            .receive(on: DispatchQueue.main)
            .assign(to: \.isPerformanceOptimal, on: self)
            .store(in: &cancellables)
        
        // Monitor FPS from frequency manager
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.currentFPS = self?.highFrequencyManager.performanceMetrics.fps ?? 60.0
            }
            .store(in: &cancellables)
    }
    
    private func startHighFrequencyUpdates() {
        highFrequencyManager.startUpdates()
    }
    
    // MARK: - View Mode Transitions
    
    /// Gets current particle state
    public var particleState: HighFrequencyStateManager.ParticleState {
        return highFrequencyManager.particleState
    }
    
    /// Gets current camera state
    public var cameraState: HighFrequencyStateManager.CameraState {
        return highFrequencyManager.cameraState
    }
    
    /// Gets current animation state
    public var animationState: HighFrequencyStateManager.AnimationState {
        return highFrequencyManager.animationState
    }
    
    /// Gets current performance metrics
    public var performanceMetrics: (fps: Double, isOptimal: Bool, frameCount: UInt64) {
        return highFrequencyManager.performanceMetrics
    }
    
    /// Gets memory usage statistics
    public var memoryUsage: (pendingUpdates: Int, particleBuffer: Int, total: Int) {
        return highFrequencyManager.memoryUsage
    }
    
    deinit {
        highFrequencyManager.stopUpdates()
    }
}
