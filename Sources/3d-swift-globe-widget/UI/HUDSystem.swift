import SwiftUI

/// Top status bar for the HUD
@available(iOS 15.0, macOS 12.0, *)
struct HUDTopBar: View {
    @ObservedObject var viewModel: GlobeViewModel
    
    var body: some View {
        HStack {
            // Left: System Status
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: .green, radius: 4)
                
                Text("SYSTEM ONLINE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(viewModel.themeManager.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(viewModel.themeManager.accentColor.opacity(0.3), lineWidth: 1)
            )
            
            Spacer()
            
            // Right: Performance Metrics
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("FPS")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(String(format: "%.0f", viewModel.fps))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 4) {
                    Text("MEM")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f MB", viewModel.memoryUsage))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .padding()
    }
}

/// Bottom control dock
@available(iOS 15.0, macOS 12.0, *)
struct HUDBottomBar: View {
    @ObservedObject var viewModel: GlobeViewModel
    
    var body: some View {
        HStack(spacing: 20) {
            
            // View Mode Toggles
            HStack(spacing: 1) {
                ViewModeButton(title: "3D", isSelected: viewModel.viewMode == .globe3D) {
                    viewModel.morphToViewMode(.globe3D)
                }
                ViewModeButton(title: "2D", isSelected: viewModel.viewMode == .globe2D) {
                    viewModel.morphToViewMode(.globe2D)
                }
            }
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(viewModel.themeManager.accentColor.opacity(0.5), lineWidth: 1)
            )
            
            // Theme Toggle
            Button(action: { viewModel.cycleTheme() }) {
                Image(systemName: "paintbrush.fill")
                    .foregroundColor(viewModel.themeManager.secondaryColor)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(viewModel.themeManager.secondaryColor.opacity(0.5), lineWidth: 1))
            }
            
            // Quick Locations (Mini)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(viewModel.nodes) { node in
                        Button(action: { viewModel.selectNode(node.id) }) {
                            Text(node.id)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(viewModel.selectedNode?.id == node.id ? viewModel.themeManager.accentColor : Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .frame(maxWidth: 200)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.bottom, 20)
    }
}

@available(iOS 15.0, macOS 12.0, *)
private struct ViewModeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(width: 40, height: 30)
                .background(isSelected ? Color.white.opacity(0.2) : Color.clear)
                .foregroundColor(isSelected ? .white : .gray)
        }
    }
}
