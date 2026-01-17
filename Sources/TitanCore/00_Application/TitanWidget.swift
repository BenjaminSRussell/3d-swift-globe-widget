import SwiftUI
import MapKit

public struct TitanWidget: View {
    // We use a simple Bool trigger for now. 
    // In a larger app, this would be an ObservableObject (Store).
    @State private var launchPacketHelper = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Updated GlobeView signature
            GlobeView(triggerAnimation: $launchPacketHelper)
                .edgesIgnoringSafeArea(.all)
                // "Global Night" / Deep Stark Tech
                // Uniform darkness across the globe.
                // 1. Heavy desaturation to remove sunlit greenery.
                // 2. Strong color multiply to tint everything deep midnight blue/black.
                // 3. Negative brightness to simulate night.
                .contrast(1.3) // Keep contrast high so city lights (if visible in texture) still pop
                .saturation(0.2) // Almost grayscale
                .brightness(-0.15) // Darken the whole view
                .colorMultiply(Color(red: 0.2, green: 0.3, blue: 0.5)) // Deep Midnight Blue tint
            
            // HUD Overlay
            VStack {
                HStack {
                    Text("TITAN ENGINE: ACTIVE")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial)
                
                Spacer()
                
                Button(action: {
                    print("DEBUG: Button clicked. Toggling trigger.")
                    launchPacketHelper = true
                }) {
                    HStack {
                        Image(systemName: "location.north.circle.fill")
                        Text("LAUNCH PACKET")
                    }
                    .padding()
                    .background(Color.cyan.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 32)
            }
        }
        .background(Color.black)
    }
}
