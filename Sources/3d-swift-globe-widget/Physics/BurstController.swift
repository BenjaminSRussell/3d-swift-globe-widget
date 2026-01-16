import Foundation
import SceneKit

/// Coordinates catastrophic failure visualizations with advanced patterns
/// Supports multiple burst types and intensity levels for different failure scenarios
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class BurstController {
    
    private let particleSystem: ParticleSystem
    private var activeBursts: [String: BurstInstance] = [:]
    
    // TODO: Implement burst pattern queueing for complex sequences
    // TODO: Add audio-visual synchronization for enhanced effects
    // TODO: Implement adaptive intensity based on failure severity
    
    public init(particleSystem: ParticleSystem) {
        self.particleSystem = particleSystem
    }
    
    /// Triggered when a connection fails catastrophically
    /// - Parameters:
    ///   - position: Cartesian position of the failure
    ///   - severity: Failure severity (0.1-1.0) affects particle count and intensity
    ///   - connectionId: Unique identifier for the failed connection
    public func triggerFailureBurst(
        at position: SCNVector3, 
        severity: Float = 1.0,
        connectionId: String = UUID().uuidString
    ) {
        // TODO: Select pattern based on failure type and severity
        // TODO: Implement multi-stage burst sequences
        
        let pattern: BurstPattern
        let intensity: Float
        
        switch severity {
        case 0.8...1.0:
            pattern = .explosive
            intensity = severity
        case 0.5..<0.8:
            pattern = .fountain
            intensity = severity * 1.2
        case 0.2..<0.5:
            pattern = .spiral
            intensity = severity * 1.5
        default:
            pattern = .shockwave
            intensity = severity * 0.8
        }
        
        // Create failure burst with red/orange gradient
        particleSystem.emitBurst(
            at: position,
            color: .red,
            pattern: pattern,
            intensity: intensity
        )
        
        // Track burst for potential follow-up effects
        let burst = BurstInstance(
            id: connectionId,
            position: position,
            pattern: pattern,
            severity: severity,
            timestamp: Date()
        )
        
        activeBursts[connectionId] = burst
        
        // Schedule secondary effects for high-severity failures
        if severity > 0.7 {
            scheduleSecondaryEffects(for: burst)
        }
    }
    
    /// Triggered for data bursts or successful operations
    /// - Parameters:
    ///   - position: Cartesian position of the success event
    ///   - magnitude: Success magnitude affects visual intensity
    public func triggerSuccessBurst(
        at position: SCNVector3, 
        magnitude: Float = 1.0
    ) {
        // TODO: Implement success-specific patterns (ascending particles, etc.)
        // TODO: Add color gradients based on data throughput
        
        let pattern: BurstPattern = magnitude > 0.7 ? .fountain : .spiral
        
        particleSystem.emitBurst(
            at: position,
            color: .green,
            pattern: pattern,
            intensity: magnitude
        )
    }
    
    /// Creates a warning burst for degraded performance
    /// - Parameters:
    ///   - position: Position of the warning event
    ///   - degradationLevel: Level of performance degradation (0.1-1.0)
    public func triggerWarningBurst(
        at position: SCNVector3,
        degradationLevel: Float = 0.5
    ) {
        // TODO: Implement pulsing warning effects
        // TODO: Add yellow/orange color transitions
        
        particleSystem.emitBurst(
            at: position,
            color: .yellow,
            pattern: .spiral,
            intensity: degradationLevel
        )
    }
    
    /// Creates a custom burst with specific parameters
    /// - Parameters:
    ///   - position: Emission position
    ///   - color: Particle color
    ///   - pattern: Burst pattern
    ///   - intensity: Particle intensity
    ///   - customId: Optional custom identifier
    public func triggerCustomBurst(
        at position: SCNVector3,
        color: UniversalColor,
        pattern: BurstPattern,
        intensity: Float,
        customId: String? = nil
    ) {
        let burstId = customId ?? UUID().uuidString
        
        particleSystem.emitBurst(
            at: position,
            color: color,
            pattern: pattern,
            intensity: intensity
        )
        
        // Track custom burst
        let burst = BurstInstance(
            id: burstId,
            position: position,
            pattern: pattern,
            severity: intensity,
            timestamp: Date()
        )
        
        activeBursts[burstId] = burst
    }
    
    /// Schedules secondary effects for high-impact failures
    private func scheduleSecondaryEffects(for burst: BurstInstance) {
        // TODO: Implement delayed secondary bursts
        // TODO: Add shockwave ring effects
        // TODO: Create lingering particle clouds
        
        // Schedule follow-up burst after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.particleSystem.emitBurst(
                at: burst.position,
                color: .orange,
                pattern: .shockwave,
                intensity: burst.severity * 0.6
            )
        }
        
        // Schedule final dissipation burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.particleSystem.emitBurst(
                at: burst.position,
                color: .yellow,
                pattern: .spiral,
                intensity: burst.severity * 0.3
            )
        }
    }
    
    /// Updates all active bursts and manages cleanup
    public func update(deltaTime: TimeInterval) {
        // TODO: Update ongoing burst animations
        // TODO: Manage burst lifecycle and cleanup
        // TODO: Handle burst interactions and overlaps
        
        particleSystem.update(deltaTime: deltaTime)
        
        // Clean up expired bursts
        let now = Date()
        activeBursts = activeBursts.filter { _, burst in
            now.timeIntervalSince(burst.timestamp) < burst.pattern.duration + 2.0
        }
    }
    
    /// Gets information about active bursts
    public var activeBurstCount: Int {
        return activeBursts.count
    }
    
    /// Clears all active bursts (for testing or reset scenarios)
    public func clearAllBursts() {
        activeBursts.removeAll()
        // TODO: Implement immediate particle system cleanup
    }
}

/// Represents an active burst instance
private struct BurstInstance {
    let id: String
    let position: SCNVector3
    let pattern: BurstPattern
    let severity: Float
    let timestamp: Date
}
