import Foundation
import QuartzCore
import SceneKit

/// Comprehensive performance monitoring system for Stage 6 optimization
/// Includes FPS monitoring, memory tracking, leak detection, and performance alerts
@available(iOS 15.0, macOS 12.0, *)
public class PerformanceMonitor: ObservableObject {
    
    // MARK: - Published Performance Metrics
    @Published public var frameRate: Double = 60.0
    @Published public var frameTime: Double = 16.67
    @Published public var memoryUsage: Double = 0.0
    @Published public var memoryPressure: MemoryPressure = .normal
    @Published public var drawCalls: Int = 0
    @Published public var triangleCount: Int = 0
    @Published public var activeAnimations: Int = 0
    @Published public var performanceScore: Double = 100.0
    
    // MARK: - Memory Pressure Levels
    public enum MemoryPressure {
        case normal, warning, critical
        
        public var color: String {
            switch self {
            case .normal: return "🟢"
            case .warning: return "🟡"
            case .critical: return "🔴"
            }
        }
    }
    
    // MARK: - Performance Alerts
    @Published public var alerts: [PerformanceAlert] = []
    
    public struct PerformanceAlert {
        public let id = UUID()
        public let type: AlertType
        public let message: String
        public let severity: Severity
        public let timestamp: Date
        
        public enum AlertType {
            case lowFPS, memoryLeak, highMemoryUsage, resourceExhaustion
        }
        
        public enum Severity {
            case info, warning, critical
        }
    }
    
    // MARK: - Private Properties
    #if os(iOS)
    private var displayLink: CADisplayLink?
    #else
    private var displayTimer: Timer?
    #endif
    private var lastUpdate: TimeInterval = 0
    private var frameCount: Int = 0
    private var frameTimestamps: [CFTimeInterval] = []
    
    // ...

    // MARK: - Update Methods
    public func start() {
        #if os(iOS)
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
        #else
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateMacOS()
        }
        #endif
    }
    
    public func stop() {
        #if os(iOS)
        displayLink?.invalidate()
        displayLink = nil
        #else
        displayTimer?.invalidate()
        displayTimer = nil
        #endif
    }
    
    #if os(iOS)
    @objc private func update(link: CADisplayLink) {
        let now = link.timestamp
        frameTimestamps.append(now)
        frameTimestamps = frameTimestamps.filter { now - $0 < 2.0 }
        
        if now - lastUpdate >= 1.0 {
            calculateMetrics()
            lastUpdate = now
        }
    }
    #else
    @objc private func updateMacOS() {
        let now = CACurrentMediaTime()
        frameTimestamps.append(now)
        frameTimestamps = frameTimestamps.filter { now - $0 < 2.0 }
        
        if now - lastUpdate >= 1.0 {
            calculateMetrics()
            lastUpdate = now
        }
    }
    #endif
    
    private func calculateMetrics() {
        // Calculate FPS
        if frameTimestamps.count >= 2 {
            let timeSpan = frameTimestamps.last! - frameTimestamps.first!
            frameRate = Double(frameTimestamps.count - 1) / timeSpan
            frameTime = 1000.0 / frameRate
        }
        
        // Get memory usage
        let mem = getMemoryUsage()
        memoryUsage = mem
        
        // Update memory pressure
        updateMemoryPressure()
        
        // Update performance score
        updatePerformanceScore()
        
        // Check for performance issues
        checkPerformanceIssues()
        
        // Update view model if available
        Task { @MainActor [weak viewModel] in
            viewModel?.fps = frameRate
            viewModel?.memoryUsage = mem
        }
        
        frameCount = 0
    }
    
    private func updateMemoryPressure() {
        if memoryUsage > memoryCriticalThreshold {
            memoryPressure = .critical
        } else if memoryUsage > memoryWarningThreshold {
            memoryPressure = .warning
        } else {
            memoryPressure = .normal
        }
    }
    
    private func checkPerformanceIssues() {
        // Check for low FPS
        if frameRate < targetFPS * 0.8 {
            addAlert(
                type: .lowFPS,
                message: "Low FPS detected: \(String(format: "%.1f", frameRate)) (target: \(targetFPS))",
                severity: frameRate < targetFPS * 0.5 ? .critical : .warning
            )
        }
        
        // Check for high memory usage
        if memoryUsage > memoryCriticalThreshold {
            addAlert(
                type: .highMemoryUsage,
                message: "Critical memory usage: \(String(format: "%.1f", memoryUsage))MB",
                severity: .critical
            )
        } else if memoryUsage > memoryWarningThreshold {
            addAlert(
                type: .highMemoryUsage,
                message: "High memory usage: \(String(format: "%.1f", memoryUsage))MB",
                severity: .warning
            )
        }
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        return 0
    }
    
    // MARK: - Public Statistics
    public func getPerformanceReport() -> PerformanceReport {
        return PerformanceReport(
            frameRate: frameRate,
            frameTime: frameTime,
            memoryUsage: memoryUsage,
            memoryPressure: memoryPressure,
            performanceScore: performanceScore,
            activeAnimations: activeAnimations,
            resourceCounters: resourceCounters,
            recentAlerts: alerts.suffix(10).map { $0 }
        )
    }
    
    public struct PerformanceReport {
        public let frameRate: Double
        public let frameTime: Double
        public let memoryUsage: Double
        public let memoryPressure: MemoryPressure
        public let performanceScore: Double
        public let activeAnimations: Int
        public let resourceCounters: [String: Int]
        public let recentAlerts: [PerformanceAlert]
    }
    
    // MARK: - Cleanup
    public func clearAlerts() {
        alerts.removeAll()
    }
    
    public func resetCounters() {
        resourceCounters.removeAll()
        activeAnimations = 0
        memorySnapshots.removeAll()
        frameTimestamps.removeAll()
    }
}
