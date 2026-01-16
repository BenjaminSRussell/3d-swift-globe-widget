import SwiftUI
import SceneKit

/// Main entry point for the 3D Globe visualization.
/// Uses the modular GraphicsEngine for rendering and state management.
@available(iOS 15.0, macOS 12.0, *)
public struct Globe3DWidget: View {
    @StateObject private var controller: ApplicationController
    
    public init() {
        let engine = GraphicsEngine()
        let networkService = NetworkService()
        let state = engine.state
        
        _controller = StateObject(wrappedValue: ApplicationController(
            engine: engine,
            networkService: networkService,
            state: state
        ))
    }
    
    public var body: some View {
        ZStack {
            SceneView(
                scene: controller.engine.scene,
                options: [.allowsCameraControl, .autoenablesDefaultLighting],
                delegate: SceneDelegate()
            )
            .onAppear {
                controller.start()
            }
            
            // Interaction Layer
            VStack {
                Spacer()
                HStack(spacing: 20) {
                    InteractionButton(title: "Fail NYC", color: .red) {
                        controller.simulateFailure(at: "NYC")
                    }
                    
                    InteractionButton(title: "Fail LAX", color: .orange) {
                        controller.simulateFailure(at: "LAX")
                    }
                    
                    InteractionButton(title: "Toggle 2D/3D", color: .blue) {
                        controller.state.viewMode = (controller.state.viewMode == .globe3D) ? .map2D : .globe3D
                    }
                }
                .padding(.bottom, 40)
            }
            
            // Performance Overlay
            PerformanceOverlay(engine: controller.engine)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

private struct InteractionButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .monospaced))
                .bold()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(color.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.3)))
        }
    }
}

// MARK: - Subviews
private struct PerformanceOverlay: View {
    @ObservedObject var engine: GraphicsEngine
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text("FPS: \(String(format: "%.1f", engine.frameRate))")
                        .foregroundColor(.green)
                    Text("Draw Calls: \(engine.drawCallCount)")
                        .foregroundColor(.yellow)
                    Text("Mode: \(engine.state.viewMode == .globe3D ? "3D" : "2D")")
                        .foregroundColor(.cyan)
                }
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color.black.opacity(0.8))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1)))
                
                Spacer()
            }
            .padding()
            Spacer()
        }
    }
}

// MARK: - Scene Delegate
private class SceneDelegate: NSObject, SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Advanced frame pacing and optimization can be implemented here
    }
}

#Preview {
    Globe3DWidget()
}
