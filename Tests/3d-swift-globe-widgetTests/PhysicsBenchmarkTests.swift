import XCTest
@testable import _3d_swift_globe_widget

@available(iOS 15.0, macOS 12.0, *)
final class PhysicsBenchmarkTests: XCTestCase {
    
    func testParticleSystemPerformance() {
        let scene = SCNScene()
        let particleSystem = ParticleSystem(scene: scene, maxParticles: 100000)
        
        measure {
            particleSystem.emitBurst(at: SCNVector3(0, 0, 0), pattern: .explosive, intensity: 1.0)
        }
    }
    
    func testCurlNoisePerformance() {
        let physics = CurlNoisePhysics()
        let positions = Array(repeating: SCNVector3(0, 0, 0), count: 10000)
        var velocities = Array(repeating: SCNVector3(0, 0, 0), count: 10000)
        
        measure {
            physics.applyCurlNoise(positions: positions, velocities: &velocities, deltaTime: 0.016)
        }
    }
}
