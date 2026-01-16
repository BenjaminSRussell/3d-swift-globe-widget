import Foundation
import SceneKit

/// Coordinates catastrophic failure visualizations
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class BurstController {
    
    private let particleSystem: ParticleSystem
    
    public init(particleSystem: ParticleSystem) {
        self.particleSystem = particleSystem
    }
    
    /// Triggered when a connection fails
    /// - Parameter position: Cartesian position of the failure
    public func triggerFailureBurst(at position: SCNVector3) {
        // Delicate bursting effect: red/orange particles
        particleSystem.emitBurst(at: position, color: .red)
    }
    
    /// Triggered for data bursts or successes
    public func triggerSuccessBurst(at position: SCNVector3) {
        particleSystem.emitBurst(at: position, color: .green)
    }
}
