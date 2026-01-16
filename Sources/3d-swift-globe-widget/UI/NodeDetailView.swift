import SwiftUI

/// Glassmorphic HUD for displaying node details
@available(iOS 15.0, macOS 12.0, *)
struct NodeDetailView: View {
    
    let node: NetworkService.Node
    let themeManager: ThemeManager
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(node.id)
                    .font(.system(.title2, design: .monospaced))
                    .bold()
                    .foregroundColor(themeManager.accentColor)
                
                Spacer()
                
                // Status Indicator
                Circle()
                    .fill(node.status == .error ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: (node.status == .error ? Color.red : Color.green).opacity(0.8), radius: 5)
                
                Text(node.status == .error ? "CRITICAL" : "ONLINE")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(node.status == .error ? .red : .green)
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Stats Grid
            VStack(alignment: .leading, spacing: 8) {
                StatRow(label: "TYPE", value: node.type)
                StatRow(label: "LATITUDE", value: String(format: "%.4f", node.lat))
                StatRow(label: "LONGITUDE", value: String(format: "%.4f", node.lon))
            }
            
            // Action Button
            Button(action: onClose) {
                HStack {
                    Spacer()
                    Text("CLOSE FEED")
                        .font(.system(.caption, design: .monospaced))
                        .bold()
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.2)))
            }
        }
        .padding()
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}
