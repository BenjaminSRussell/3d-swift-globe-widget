import SwiftUI

/// Main entry point for the 3D Globe visualization.
/// Phase 3 Enhanced: Network topology, particle physics, and night mode
@available(iOS 15.0, macOS 12.0, *)
public struct Globe3DWidget: View {
    
    @StateObject private var viewModel = GlobeViewModel()
    @StateObject private var graphicsEngine = GraphicsEngine()
    @StateObject private var performanceMonitor: PerformanceMonitor
    
    // Phase 3 State
    @State private var isNightMode: Bool = true
    @State private var showNetworkTopology: Bool = true
    @State private var showParticleEffects: Bool = true
    @State private var selectedConnectionId: String? = nil
    
    public init() {
        let vm = GlobeViewModel()
        _viewModel = StateObject(wrappedValue: vm)
        _performanceMonitor = StateObject(wrappedValue: PerformanceMonitor())
    }
    
    public var body: some View {
        ZStack {
            // Main Globe Layer with Phase 3 Enhancements
            MapKitGlobeView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    // Network Topology Overlay
                    NetworkTopologyOverlay(
                        graphicsEngine: graphicsEngine,
                        isVisible: showNetworkTopology,
                        selectedConnectionId: $selectedConnectionId
                    )
                )
                .overlay(
                    // Particle Effects Overlay
                    ParticleEffectsOverlay(
                        graphicsEngine: graphicsEngine,
                        isVisible: showParticleEffects
                    )
                )
            
            // Enhanced HUD Layer with Phase 3 Controls
            VStack {
                // Top Bar (System Status & Network Metrics)
                HUDTopBar(viewModel: viewModel)
                    .padding(.top, 40)
                    .overlay(
                        // Night Mode Toggle
                        HStack {
                            Spacer()
                            NightModeToggle(
                                isNightMode: $isNightMode,
                                graphicsEngine: graphicsEngine
                            )
                            .padding(.trailing, 20)
                        }
                    )
                
                HStack {
                    Spacer()
                    // Enhanced Node Detail HUD with Network Info
                    if let selectedNode = viewModel.selectedNode {
                        EnhancedNodeDetailView(
                            node: selectedNode,
                            graphicsEngine: graphicsEngine,
                            themeManager: viewModel.themeManager,
                            onClose: { viewModel.clearSelection() }
                        )
                        .padding()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .animation(.spring(), value: viewModel.selectedNode?.id)
                    }
                }
                
                Spacer()
                
                // Enhanced Bottom Dock with Phase 3 Controls
                HUDBottomBar(viewModel: viewModel)
                    .overlay(
                        // Network Controls
                        NetworkControlsOverlay(
                            graphicsEngine: graphicsEngine,
                            showNetworkTopology: $showNetworkTopology,
                            showParticleEffects: $showParticleEffects,
                            selectedConnectionId: $selectedConnectionId
                        )
                    )
            }
            .padding()
            
            // Performance Overlay (Phase 3)
            if true { // Always show performance overlay for now
                PerformanceOverlay(
                    performanceMonitor: performanceMonitor,
                    graphicsEngine: graphicsEngine
                )
                .padding(.leading, 20)
                .padding(.top, 100)
            }
        }
        .onAppear {
            performanceMonitor.start()
            graphicsEngine.updateForNightMode(isNightMode)
        }
        .onDisappear {
            performanceMonitor.stop()
            graphicsEngine.cleanup()
        }
        .onChange(of: isNightMode) { newValue in
            graphicsEngine.updateForNightMode(newValue)
        }
    }
}

// MARK: - Phase 3 Enhanced Components

/// Network topology overlay for arc visualization
@available(iOS 15.0, macOS 12.0, *)
private struct NetworkTopologyOverlay: View {
    let graphicsEngine: GraphicsEngine
    let isVisible: Bool
    @Binding var selectedConnectionId: String?
    
    var body: some View {
        if isVisible {
            Color.clear
                .onTapGesture {
                    // Handle connection selection
                    handleConnectionSelection()
                }
        }
    }
    
    private func handleConnectionSelection() {
        // Implementation for selecting network connections
        // This would use hit testing on the arc system
    }
}

/// Particle effects overlay for connection failures
private struct ParticleEffectsOverlay: View {
    let graphicsEngine: GraphicsEngine
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            Color.clear
                .allowsHitTesting(false)
        }
    }
}

/// Night mode toggle control
private struct NightModeToggle: View {
    @Binding var isNightMode: Bool
    let graphicsEngine: GraphicsEngine
    
    var body: some View {
        Button(action: {
            isNightMode.toggle()
            graphicsEngine.toggleNightMode()
        }) {
            Image(systemName: isNightMode ? "moon.fill" : "sun.max.fill")
                .font(.system(size: 20))
                .foregroundColor(isNightMode ? .yellow : .orange)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isNightMode ? Color.yellow : Color.orange, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Enhanced node detail view with network information
private struct EnhancedNodeDetailView: View {
    let node: NetworkService.Node
    let graphicsEngine: GraphicsEngine
    let themeManager: ThemeManager
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(node.id)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.secondaryColor)
                }
            }
            
            // Node Information
            NodeInfoSection(node: node, themeManager: themeManager)
            
            // Network Connections
            NetworkConnectionsSection(nodeId: node.id, graphicsEngine: graphicsEngine, themeManager: themeManager)
            
            // Failure Controls
            FailureControlsSection(nodeId: node.id, graphicsEngine: graphicsEngine, themeManager: themeManager)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

/// Node information section
private struct NodeInfoSection: View {
    let node: NetworkService.Node
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            InfoRow(title: "Type", value: node.type, themeManager: themeManager)
            InfoRow(title: "Status", value: "\(node.status)", themeManager: themeManager)
            InfoRow(title: "Load", value: "\(Int(node.load * 100))%", themeManager: themeManager)
            InfoRow(title: "Location", value: String(format: "%.4f, %.4f", node.lat, node.lon), themeManager: themeManager)
        }
    }
}

/// Network connections section
private struct NetworkConnectionsSection: View {
    let nodeId: String
    let graphicsEngine: GraphicsEngine
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Network Connections")
                .font(.headline)
                .foregroundColor(.white)
            
            // Display connected nodes
            ForEach(getConnectedNodes(), id: \.id) { connectedNode in
                HStack {
                    Text(connectedNode.id)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Focus") {
                        graphicsEngine.focusCamera(on: connectedNode)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                }
            }
        }
    }
    
    private func getConnectedNodes() -> [NetworkService.Node] {
        // Get nodes connected to this nodeId
        return graphicsEngine.networkService.nodes.filter { node in
            graphicsEngine.networkService.connections.contains { conn in
                (conn.sourceId == nodeId && conn.targetId == node.id) ||
                (conn.targetId == nodeId && conn.sourceId == node.id)
            }
        }
    }
}

/// Failure controls section
private struct FailureControlsSection: View {
    let nodeId: String
    let graphicsEngine: GraphicsEngine
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Failure Simulation")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Button("Timeout") {
                    graphicsEngine.triggerConnectionFailure(at: nodeId, type: ConnectionFailurePhysics.FailureType.timeout)
                }
                .failureButtonStyle()
                
                Button("Connection Lost") {
                    graphicsEngine.triggerConnectionFailure(at: nodeId, type: ConnectionFailurePhysics.FailureType.connectionLost)
                }
                .failureButtonStyle()
                
                Button("Overload") {
                    graphicsEngine.triggerConnectionFailure(at: nodeId, type: ConnectionFailurePhysics.FailureType.overload)
                }
                .failureButtonStyle()
            }
        }
    }
}

/// Network controls overlay
private struct NetworkControlsOverlay: View {
    let graphicsEngine: GraphicsEngine
    @Binding var showNetworkTopology: Bool
    @Binding var showParticleEffects: Bool
    @Binding var selectedConnectionId: String?
    
    var body: some View {
        HStack(spacing: 16) {
            // Network topology toggle
            ToggleButton(
                title: "Network",
                isOn: $showNetworkTopology,
                color: .blue
            )
            
            // Particle effects toggle
            ToggleButton(
                title: "Particles",
                isOn: $showParticleEffects,
                color: .purple
            )
            
            // Clear selection
            Button("Clear Selection") {
                selectedConnectionId = nil
            }
            .buttonStyle(SecondaryButtonStyle())
            
            // Trigger cascade failure
            Button("Cascade") {
                let nodeIds = ["NYC", "LAX", "LON"]
                graphicsEngine.triggerCascadeFailure(nodeIds: nodeIds)
            }
            .buttonStyle(DangerButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

/// Performance overlay
private struct PerformanceOverlay: View {
    let performanceMonitor: PerformanceMonitor
    let graphicsEngine: GraphicsEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.green)
            
            HStack {
                Text("FPS: \(String(format: "%.1f", graphicsEngine.frameRate))")
                    .foregroundColor(.green)
                    .font(.caption)
                
                Spacer()
                
                Text("LOD: \(graphicsEngine.state.currentFPS >= 30 ? "Good" : "Low")")
                    .foregroundColor(graphicsEngine.state.currentFPS >= 30 ? .green : .orange)
                    .font(.caption)
            }
            
            Text("Particles: 0")
                .foregroundColor(.cyan)
                .font(.caption)
            
            Text("Arcs: 0")
                .foregroundColor(.blue)
                .font(.caption)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

// MARK: - Helper Views

private struct InfoRow: View {
    let title: String
    let value: String
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Text(title + ":")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

private struct ToggleButton: View {
    let title: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        Button(title) {
            isOn.toggle()
        }
        .buttonStyle(ToggleButtonStyle(isOn: isOn, color: color))
    }
}

struct ToggleButtonStyle: ButtonStyle {
    let isOn: Bool
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isOn ? color : Color.gray.opacity(0.3))
            )
            .foregroundColor(isOn ? .white : .white.opacity(0.7))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct FailureButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    Globe3DWidget()
}
