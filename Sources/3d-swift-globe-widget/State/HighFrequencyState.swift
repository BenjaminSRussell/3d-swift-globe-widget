import Foundation
import simd
import Metal

/// High-frequency state management for 60 FPS updates
/// Stage 7: State Management - Frequency-based state separation
@available(iOS 15.0, macOS 12.0, *)
public class HighFrequencyState {
    
    // MARK: - State Frequency Categories
    
    public enum UpdateFrequency: Int, CaseIterable {
        case realtime = 60    // 60 FPS - particle positions, camera
        case animation = 30   // 30 FPS - UI animations, transitions  
        case simulation = 20  // 20 FPS - network simulation updates
        case ui = 5          // 5 FPS - user interactions, selections
        case data = 1        // 1 FPS - server lists, topology changes
        
        var interval: TimeInterval {
            return 1.0 / TimeInterval(rawValue)
        }
    }
    
    // MARK: - Particle State (Realtime - 60 FPS)
    
    public struct ParticleState {
        public var positions: [SIMD3<Float>]
        public var velocities: [SIMD3<Float>]
        public var life: [Float]
        public var count: Int
        public var maxCount: Int
        
        public init(maxCount: Int = 100_000) {
            self.maxCount = maxCount
            self.positions = Array(repeating: SIMD3<Float>(0, 0, 0), count: maxCount)
            self.velocities = Array(repeating: SIMD3<Float>(0, 0, 0), count: maxCount)
            self.life = Array(repeating: 0.0, count: maxCount)
            self.count = 0
        }
        
        public mutating func updateParticle(at index: Int, position: SIMD3<Float>, velocity: SIMD3<Float>, life: Float) {
            guard index < maxCount else { return }
            positions[index] = position
            velocities[index] = velocity
            self.life[index] = life
        }
        
        public mutating func setParticleCount(_ count: Int) {
            self.count = min(count, maxCount)
        }
    }
    
    // MARK: - Camera State (Realtime - 60 FPS)
    
    public struct CameraState {
        public var position: SIMD3<Float>
        public var target: SIMD3<Float>
        public var up: SIMD3<Float>
        public var needsUpdate: Bool
        public var fieldOfView: Float
        public var aspectRatio: Float
        
        public init() {
            self.position = SIMD3<Float>(0, 0, 5)
            self.target = SIMD3<Float>(0, 0, 0)
            self.up = SIMD3<Float>(0, 1, 0)
            self.needsUpdate = false
            self.fieldOfView = Float.pi / 3.0 // 60 degrees
            self.aspectRatio = 16.0 / 9.0
        }
        
        public mutating func update(position: SIMD3<Float>, target: SIMD3<Float>) {
            self.position = position
            self.target = target
            self.needsUpdate = true
        }
        
        public mutating func markUpdated() {
            self.needsUpdate = false
        }
    }
    
    // MARK: - Animation State (Realtime - 60 FPS)
    
    public struct AnimationState {
        public var time: TimeInterval
        public var deltaTime: TimeInterval
        public var frameCount: UInt64
        public var isPlaying: Bool
        public var timeScale: Float
        
        public init() {
            self.time = 0.0
            self.deltaTime = 1.0 / 60.0
            self.frameCount = 0
            self.isPlaying = true
            self.timeScale = 1.0
        }
        
        public mutating func update(deltaTime: TimeInterval) {
            guard isPlaying else { return }
            
            self.deltaTime = deltaTime * timeScale
            time += self.deltaTime
            frameCount += 1
        }
        
        public mutating func play() {
            isPlaying = true
        }
        
        public mutating func pause() {
            isPlaying = false
        }
        
        public mutating func setTimeScale(_ scale: Float) {
            timeScale = max(0.0, scale)
        }
    }
    
    // MARK: - Properties
    
    public var particleState: ParticleState
    public var cameraState: CameraState
    public var animationState: AnimationState
    
    // Update tracking
    private var lastUpdateTime: [UpdateFrequency: TimeInterval]
    private var frameCount: UInt64
    
    // MARK: - Initialization
    
    public init(maxParticles: Int = 100_000) {
        self.particleState = ParticleState(maxCount: maxParticles)
        self.cameraState = CameraState()
        self.animationState = AnimationState()
        self.lastUpdateTime = Dictionary(uniqueKeysWithValues: UpdateFrequency.allCases.map { ($0, 0.0) })
        self.frameCount = 0
    }
    
    // MARK: - High-Frequency Update Methods
    
    /// Updates particle at specific index (60 FPS)
    public mutating func updateParticle(at index: Int, position: SIMD3<Float>, velocity: SIMD3<Float>, life: Float) {
        particleState.updateParticle(at: index, position: position, velocity: velocity, life: life)
    }
    
    /// Updates camera state (60 FPS)
    public mutating func updateCamera(position: SIMD3<Float>, target: SIMD3<Float>) {
        cameraState.update(position: position, target: target)
    }
    
    /// Updates animation state (60 FPS)
    public mutating func updateAnimation(deltaTime: TimeInterval) {
        animationState.update(deltaTime: deltaTime)
        frameCount += 1
    }
    
    /// Sets particle count (triggers re-render)
    public mutating func setParticleCount(_ count: Int) {
        particleState.setParticleCount(count)
    }
    
    /// Marks camera as updated
    public mutating func markCameraUpdated() {
        cameraState.markUpdated()
    }
    
    // MARK: - Frequency-Based Update Checking
    
    /// Checks if update should run for given frequency
    public func shouldUpdate(frequency: UpdateFrequency, currentTime: TimeInterval) -> Bool {
        let lastUpdate = lastUpdateTime[frequency] ?? 0.0
        return currentTime - lastUpdate >= frequency.interval
    }
    
    /// Marks frequency as updated
    public mutating func markUpdated(frequency: UpdateFrequency, currentTime: TimeInterval) {
        lastUpdateTime[frequency] = currentTime
    }
    
    /// Gets current frame count
    public var currentFrameCount: UInt64 {
        return frameCount
    }
}
