import SwiftUI
import SceneKit

/// Main entry point for the 3D Globe visualization.
/// Uses the modular GraphicsEngine for rendering and state management.
@available(iOS 15.0, macOS 12.0, *)
@available(iOS 15.0, macOS 12.0, *)
public struct Globe3DWidget: View {
    
    @StateObject private var viewModel = GlobeViewModel()
    
    public init() {}
    
    public var body: some View {
        ZStack {
            MapKitGlobeView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
                
            // HUD Overlay (Top Right)
            VStack {
                HStack {
                    Spacer()
                    if let selectedNode = viewModel.selectedNode {
                        NodeDetailView(
                            node: selectedNode,
                            themeManager: viewModel.themeManager,
                            onClose: { viewModel.clearSelection() }
                        )
                        .padding()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .animation(.spring(), value: viewModel.selectedNode?.id)
                    }
                }
                Spacer()
            }
            
            // Interaction Layer
            VStack {
                Spacer()
                
                // Tour Network Controls
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.nodes) { node in
                            InteractionButton(
                                title: node.id,
                                color: node.status == .error ? .red : viewModel.themeManager.accentColor
                            ) {
                                viewModel.selectNode(node.id)
                            }
                        }
                        
                        // Theme Toggle
                        InteractionButton(title: "Theme", color: viewModel.themeManager.secondaryColor) {
                            viewModel.cycleTheme()
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
        }
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

#Preview {
    Globe3DWidget()
}
