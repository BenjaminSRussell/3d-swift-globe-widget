import XCTest
@testable import _3d_swift_globe_widget

@available(iOS 15.0, macOS 12.0, *)
final class IntegratedParticleSystemTests: XCTestCase {
    
    var integratedSystem: IntegratedParticleSystem!
    var scene: SCNScene!
    
    override func setUp() {
        super.setUp()
        scene = SCNScene()
        integratedSystem = IntegratedParticleSystem(scene: scene, maxParticles: 10000)
    }
    
    func testIntegratedBurstEmission() {
        let position = SCNVector3(0, 0, 0)
        
        // Test all burst patterns with audio and spatial culling
        integratedSystem.emitBurst(at: position, pattern: .explosive, enableAudio: true)
        integratedSystem.emitBurst(at: position, pattern: .fountain, enableAudio: true)
        integratedSystem.emitBurst(at: position, pattern: .spiral, enableAudio: true)
        integratedSystem.emitBurst(at: position, pattern: .shockwave, enableAudio: true)
        
        let stats = integratedSystem.performanceStats
        XCTAssertEqual(stats.activeEmitters, 4)
        XCTAssertTrue(stats.audioEngineRunning)
        XCTAssertGreaterThan(stats.totalParticles, 0)
    }
    
    func testSpatialPartitioningIntegration() {
        // Create particles at different positions
        let positions = [
            SCNVector3(10, 0, 0),
            SCNVector3(-10, 0, 0),
            SCNVector3(0, 10, 0),
            SCNVector3(0, -10, 0),
            SCNVector3(0, 0, 10),
            SCNVector3(0, 0, -10)
        ]
        
        for position in positions {
            integratedSystem.emitBurst(at: position, pattern: .explosive, enableSpatialCulling: true)
        }
        
        integratedSystem.update(deltaTime: 0.016)
        
        let stats = integratedSystem.performanceStats
        XCTAssertGreaterThan(stats.cullingEfficiency, 0.0)
        XCTAssertGreaterThan(stats.visibleParticles, 0)
    }
    
    func testAudioVisualSynchronization() {
        let position = SCNVector3(5, 5, 5)
        
        integratedSystem.emitBurst(
            at: position,
            pattern: .explosive,
            intensity: 0.8,
            enableAudio: true
        )
        
        let stats = integratedSystem.performanceStats
        XCTAssertGreaterThan(stats.syncQuality, 0.0)
        XCTAssertTrue(stats.audioEngineRunning)
    }
    
    func testPerformanceMonitoring() {
        // Create multiple bursts to test performance
        for i in 0..<10 {
            let position = SCNVector3(
                Float.random(in: -50...50),
                Float.random(in: -50...50),
                Float.random(in: -50...50)
            )
            integratedSystem.emitBurst(at: position, pattern: .explosive, intensity: 0.5)
        }
        
        integratedSystem.update(deltaTime: 0.016)
        
        let stats = integratedSystem.performanceStats
        XCTAssertGreaterThan(stats.totalParticles, 0)
        XCTAssertGreaterThan(stats.memoryUsage, 0)
        XCTAssertNotNil(stats.performanceGrade)
    }
    
    func testAmbientEffects() {
        integratedSystem.triggerAmbientEffects()
        
        let stats = integratedSystem.performanceStats
        XCTAssertGreaterThan(stats.totalParticles, 0)
        XCTAssertTrue(stats.audioEngineRunning)
    }
    
    func testSystemCleanup() {
        // Create some particles
        integratedSystem.emitBurst(at: SCNVector3(0, 0, 0), pattern: .explosive)
        
        let beforeStats = integratedSystem.performanceStats
        XCTAssertGreaterThan(beforeStats.activeEmitters, 0)
        
        // Stop all effects
        integratedSystem.stopAllEffects()
        
        let afterStats = integratedSystem.performanceStats
        XCTAssertEqual(afterStats.activeEmitters, 0)
        XCTAssertEqual(afterStats.totalParticles, 0)
    }
}

@available(iOS 15.0, macOS 12.0, *)
final class SpatialPartitioningTests: XCTestCase {
    
    var spatialSystem: SpatialPartitioningSystem!
    
    override func setUp() {
        super.setUp()
        let bounds = SpatialPartitioningSystem.AABB(
            center: SCNVector3(0, 0, 0),
            size: SCNVector3(100, 100, 100)
        )
        spatialSystem = SpatialPartitioningSystem(bounds: bounds, cellSize: 5.0)
    }
    
    func testOctreeInsertion() {
        let particles = createTestParticles(count: 100)
        spatialSystem.update(particles: particles)
        
        let stats = spatialSystem.getStatistics()
        XCTAssertEqual(stats.totalParticles, 100)
        XCTAssertGreaterThan(stats.octreeDepth, 0)
    }
    
    func testGridPartitioning() {
        let particles = createTestParticles(count: 50)
        spatialSystem.update(particles: particles)
        
        let stats = spatialSystem.getStatistics()
        XCTAssertGreaterThan(stats.gridUtilization, 0.0)
        XCTAssertLessThanOrEqual(stats.gridUtilization, 1.0)
    }
    
    func testFrustumCulling() {
        let particles = createTestParticles(count: 200)
        spatialSystem.update(particles: particles)
        
        let frustum = SpatialPartitioningSystem.Frustum(
            position: simd_float3(0, 0, 0),
            direction: simd_float3(0, 0, -1),
            fov: 60.0,
            aspect: 1.0,
            nearPlane: 0.1,
            farPlane: 100.0
        )
        
        let visibleParticles = spatialSystem.queryVisibleParticles(frustum: frustum)
        XCTAssertLessThanOrEqual(visibleParticles.count, 200)
    }
    
    func testSphereQuery() {
        let particles = createTestParticles(count: 100)
        spatialSystem.update(particles: particles)
        
        let nearbyParticles = spatialSystem.queryNearbyParticles(
            center: SCNVector3(0, 0, 0),
            radius: 10.0
        )
        
        XCTAssertLessThanOrEqual(nearbyParticles.count, 100)
    }
    
    private func createTestParticles(count: Int) -> [SpatialPartitioningSystem.ParticleReference] {
        var particles: [SpatialPartitioningSystem.ParticleReference] = []
        
        for i in 0..<count {
            let particle = SpatialPartitioningSystem.ParticleReference(
                id: i,
                position: SCNVector3(
                    Float.random(in: -50...50),
                    Float.random(in: -50...50),
                    Float.random(in: -50...50)
                ),
                velocity: SCNVector3(0, 0, 0),
                life: 1.0,
                size: 0.01,
                color: .red
            )
            particles.append(particle)
        }
        
        return particles
    }
}

@available(iOS 15.0, macOS 12.0, *)
final class AudioVisualSyncTests: XCTestCase {
    
    var audioSync: AudioVisualSyncSystem!
    
    override func setUp() {
        super.setUp()
        audioSync = AudioVisualSyncSystem()
    }
    
    func testSyncEventCreation() {
        let position = SCNVector3(10, 5, 0)
        
        audioSync.triggerSyncEvent(
            type: .explosion,
            at: position,
            intensity: 0.8,
            pattern: .explosive
        )
        
        let stats = audioSync.syncStatistics
        XCTAssertGreaterThan(stats.activeEvents, 0)
        XCTAssertTrue(stats.audioEngineRunning)
    }
    
    func testMultipleSoundTypes() {
        let position = SCNVector3(0, 0, 0)
        
        for soundType in AudioVisualSyncSystem.SoundType.allCases {
            audioSync.triggerSyncEvent(
                type: soundType,
                at: position,
                intensity: 0.5,
                pattern: .explosive
            )
        }
        
        let stats = audioSync.syncStatistics
        XCTAssertEqual(stats.activeEvents, AudioVisualSyncSystem.SoundType.allCases.count)
    }
    
    func testAmbientAudio() {
        audioSync.triggerAmbientAudio(intensity: 0.4)
        
        let stats = audioSync.syncStatistics
        XCTAssertGreaterThan(stats.activeEvents, 0)
        XCTAssertTrue(stats.audioEngineRunning)
    }
    
    func testAudioStop() {
        // Create some events
        audioSync.triggerSyncEvent(type: .explosion, at: SCNVector3(0, 0, 0))
        audioSync.triggerSyncEvent(type: .fountain, at: SCNVector3(1, 1, 1))
        
        let beforeStats = audioSync.syncStatistics
        XCTAssertGreaterThan(beforeStats.activeEvents, 0)
        
        // Stop all audio
        audioSync.stopAllAudio()
        
        let afterStats = audioSync.syncStatistics
        XCTAssertEqual(afterStats.activeEvents, 0)
    }
}

@available(iOS 15.0, macOS 12.0, *)
final class PerformanceBenchmarkTests: XCTestCase {
    
    func testIntegratedSystemPerformance() {
        let scene = SCNScene()
        let system = IntegratedParticleSystem(scene: scene, maxParticles: 50000)
        
        measure {
            system.emitBurst(at: SCNVector3(0, 0, 0), pattern: .explosive, intensity: 1.0)
            system.update(deltaTime: 0.016)
        }
    }
    
    func testSpatialPartitioningPerformance() {
        let bounds = SpatialPartitioningSystem.AABB(
            center: SCNVector3(0, 0, 0),
            size: SCNVector3(1000, 1000, 1000)
        )
        let system = SpatialPartitioningSystem(bounds: bounds)
        
        let particles = (0..<10000).map { i in
            SpatialPartitioningSystem.ParticleReference(
                id: i,
                position: SCNVector3(
                    Float.random(in: -500...500),
                    Float.random(in: -500...500),
                    Float.random(in: -500...500)
                ),
                velocity: SCNVector3(0, 0, 0),
                life: 1.0,
                size: 0.01,
                color: .red
            )
        }
        
        measure {
            system.update(particles: particles)
            let _ = system.queryNearbyParticles(center: SCNVector3(0, 0, 0), radius: 100.0)
        }
    }
    
    func testAudioSyncPerformance() {
        let system = AudioVisualSyncSystem()
        
        measure {
            system.triggerSyncEvent(type: .explosion, at: SCNVector3(0, 0, 0))
            system.update(deltaTime: 0.016)
        }
    }
}
