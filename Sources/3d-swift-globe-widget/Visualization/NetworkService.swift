import Foundation
import Combine

/// Manages network topology and real-time updates
@available(iOS 15.0, macOS 12.0, *)
public class NetworkService: ObservableObject {
    
    public struct Node: Identifiable {
        public let id: String
        public let lat: Double
        public let lon: Double
        public let type: String
        public var status: Status
        
        public enum Status {
            case active, inactive, error
        }
    }
    
    public struct Connection: Identifiable {
        public let id: String
        public let sourceId: String
        public let targetId: String
        public var weight: Double
    }
    
    @Published public var nodes: [Node] = []
    @Published public var connections: [Connection] = []
    
    public init() {}
    
    /// Batch update for nodes and connections to optimize performance
    public func updateNetwork(nodes: [Node], connections: [Connection]) {
        self.nodes = nodes
        self.connections = connections
    }
    
    /// Loads initial network data
    public func loadData() {
        let mockNodes = [
            Node(id: "NYC", lat: 40.7128, lon: -74.0060, type: "DataCenter", status: .active),
            Node(id: "LAX", lat: 34.0522, lon: -118.2437, type: "EdgeNode", status: .active),
            Node(id: "LON", lat: 51.5074, lon: -0.1278, type: "DataCenter", status: .active)
        ]
        
        let mockConns = [
            Connection(id: "NYC-LAX", sourceId: "NYC", targetId: "LAX", weight: 0.9),
            Connection(id: "NYC-LON", sourceId: "NYC", targetId: "LON", weight: 0.7)
        ]
        
        updateNetwork(nodes: mockNodes, connections: mockConns)
    }
}
