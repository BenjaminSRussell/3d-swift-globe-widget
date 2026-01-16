import XCTest
@testable import _3d_swift_globe_widget

@available(iOS 15.0, macOS 12.0, *)
final class PhysicsSystemTests: XCTestCase {
    
    var particleSystem: ParticleSystem!
    var burstController: BurstController!
    var scene: SCNScene!
    
    override func setUp() {
        super.setUp()
        scene = SCNScene()
        particleSystem = ParticleSystem(scene: scene, maxParticles: 1000)
        burstController = BurstController(particleSystem: particleSystem)
    }
    
    func testBurstPatternCreation() {
        let position = SCNVector3(0, 0, 0)
        
        // Test each burst pattern
        particleSystem.emitBurst(at: position, pattern: .explosive)
        particleSystem.emitBurst(at: position, pattern: .fountain)
        particleSystem.emitBurst(at: position, pattern: .spiral)
        particleSystem.emitBurst(at: position, pattern: .shockwave)
        
        // Verify no crashes
        XCTAssertTrue(true)
    }
    
    func testBurstControllerSeverityLevels() {
        let position = SCNVector3(1, 2, 3)
        
        // Test different severity levels
        burstController.triggerFailureBurst(at: position, severity: 1.0)
        burstController.triggerFailureBurst(at: position, severity: 0.5)
        burstController.triggerFailureBurst(at: position, severity: 0.1)
        
        XCTAssertEqual(burstController.activeBurstCount, 3)
    }
    
    func testPerformanceOptimization() {
        let optimizer = ParticlePerformanceOptimizer()
        
        // Test LOD calculation
        let lod = optimizer.getLODLevel(cameraDistance: 750)
        XCTAssertEqual(lod.particleCount, 10000)
        
        // Test particle count optimization
        let optimizedCount = optimizer.optimizeParticleCount(
            currentCount: 50000,
            frameTime: 0.020 // 20ms - over budget
        )
        XCTAssertEqual(optimizedCount, 25000)
    }
}
