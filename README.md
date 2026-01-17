# Titan Visualization Engine 🌍

> **"Stark Tech" Visual Intelligence Platform**
> A high-fidelity, native macOS 3D globe visualization engine built with MapKit and SwiftUI.

## 💎 Features

### 🌑 Global Night Mode ("Stark Tech" Aesthetic)
- **Uniform Darkness**: A deep, midnight-blue filter applied globally to simulate a permanent night side.
- **High Clarity**: Tuned contrast and metallic saturation levels for a premium, aerospace feel.
- **No Daylight**: The sun never rises on the Titan Engine.

### 💡 Data Visualizations
- **Server Clusters**: High-density "Light Pollution" simulation. Tiny, glowing white/blue dots represent major global data centers (US-East, London, Tokyo, etc.).
- **Magnetic Arc Packet**: A "White Hot" data packet traverses the globe (NYC -> LA) with a perfectly synchronized, growing geodesic trail.
- **Electric Blue Force Field**: All data points feature a sophisticated electric blue glow using Core Animation layers.

### 🚀 Performance
- **Native Metal/MapKit**: Uses Apple's `satelliteFlyover` for photorealistic 3D rendering.
- **60 FPS Animation**: Custom `Task`-based rendering loops ensure silky smooth packet and trail movement.
- **Thread-Safe**: Modern Swift Concurrency actors manage state to prevent UI jank, even under load.

## 🛠 Architecture

The project has been refactored into a clean, honest architecture (`TitanCore`):
- **Map System**: `GlobeView` (NSViewRepresentable) handles the `MKMapView` and custom `rendererFor` overlays.
- **Visualizers**: 
  - `ArcVisualizer`: Geodesic math and trail animation.
  - `ServerLightsVisualizer`: Static data generation for server hubs.
- **App Layer**: `TitanWidget` (SwiftUI) composes the visual layers and applies the "Stark Tech" color grading.

## 🏃‍♂️ How to Run

**Requirements**: macOS 12+ (Developed on macOS 12)

```bash
# Clone the repository
git clone <your-repo-url>

# Build and Run
swift run TitanApp
```

## 🎮 Controls
- **Launch Packet**: Fires the NYC -> LA data packet animation.
- **Map Interaction**: Full Zoom, Pan, Pitch, and Rotate support.

---
*Powered by TitanCore*
