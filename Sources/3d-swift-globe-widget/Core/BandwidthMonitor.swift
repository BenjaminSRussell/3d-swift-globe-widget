import Foundation
import Combine
import Network

/// Stage 6: Network bandwidth monitoring system
/// Monitors data transfer rates, connection quality, and network performance
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class BandwidthMonitor: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var currentBandwidth: Double = 0.0 // Mbps
    @Published public var averageBandwidth: Double = 0.0 // Mbps
    @Published public var peakBandwidth: Double = 0.0 // Mbps
    @Published public var utilization: Double = 0.0 // Percentage
    @Published public var latency: Double = 0.0 // ms
    @Published public var packetLoss: Double = 0.0 // Percentage
    @Published public var connectionQuality: ConnectionQuality = .excellent
    
    // MARK: - Private Properties
    private let networkService: NetworkService
    private let performanceMonitor: PerformanceMonitor
    private var bandwidthHistory: [Double] = []
    private let maxHistoryLength = 60
    private var monitoringTimer: Timer?
    private var pathMonitor: NWPathMonitor?
    
    // MARK: - Initialization
    public init(networkService: NetworkService, performanceMonitor: PerformanceMonitor) {
        self.networkService = networkService
        self.performanceMonitor = performanceMonitor
        setupNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    public func startMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
        
        pathMonitor?.start(queue: .main)
    }
    
    public func stopMonitoring() {
        monitoringTimer?.invalidate()
        pathMonitor?.cancel()
    }
    
    public func getBandwidthReport() -> BandwidthReport {
        return BandwidthReport(
            currentBandwidth: currentBandwidth,
            averageBandwidth: averageBandwidth,
            peakBandwidth: peakBandwidth,
            utilization: utilization,
            latency: latency,
            packetLoss: packetLoss,
            connectionQuality: connectionQuality,
            timestamp: Date()
        )
    }
    
    // MARK: - Private Methods
    private func setupNetworkMonitoring() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            self?.updateConnectionQuality(path: path)
        }
    }
    
    private func updateMetrics() {
        // Simulate bandwidth calculation (replace with actual network monitoring)
        let simulatedBandwidth = Double.random(in: 10...100)
        updateBandwidth(bandwidth: simulatedBandwidth)
        
        // Simulate latency
        latency = Double.random(in: 5...50)
        
        // Simulate packet loss
        packetLoss = Double.random(in: 0...2)
        
        updateConnectionQuality()
    }
    
    private func updateBandwidth(bandwidth: Double) {
        currentBandwidth = bandwidth
        
        // Update history
        bandwidthHistory.append(bandwidth)
        if bandwidthHistory.count > maxHistoryLength {
            bandwidthHistory.removeFirst()
        }
        
        // Calculate average
        averageBandwidth = bandwidthHistory.reduce(0, +) / Double(bandwidthHistory.count)
        
        // Update peak
        peakBandwidth = max(peakBandwidth, bandwidth)
        
        // Calculate utilization (assuming 100 Mbps max)
        utilization = min((bandwidth / 100.0) * 100, 100.0)
    }
    
    private func updateConnectionQuality(path: NWPath? = nil) {
        let quality = calculateConnectionQuality()
        connectionQuality = quality
    }
    
    private func calculateConnectionQuality() -> ConnectionQuality {
        if utilization > 90 || packetLoss > 5 {
            return .poor
        } else if utilization > 70 || packetLoss > 2 || latency > 100 {
            return .fair
        } else if utilization > 50 || latency > 50 {
            return .good
        } else {
            return .excellent
        }
    }
    
    // MARK: - Supporting Types
    public enum ConnectionQuality {
        case excellent
        case good
        case fair
        case poor
        
        var description: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            }
        }
    }
}

public struct BandwidthReport {
    public let currentBandwidth: Double
    public let averageBandwidth: Double
    public let peakBandwidth: Double
    public let utilization: Double
    public let latency: Double
    public let packetLoss: Double
    public let connectionQuality: BandwidthMonitor.ConnectionQuality
    public let timestamp: Date
}
