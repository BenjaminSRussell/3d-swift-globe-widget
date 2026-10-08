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
- **Data & Config** (platform-neutral, unit-tested on macOS and Linux): `GeoMath` (projection, great-circle distance, arc sampling), `GlobeDataLoader` (GeoJSON), `Configuration`, `DependencyContainer`, `BookmarkStore` / `GlobeSession` / `CameraFraming`.

## 🏃‍♂️ How to Run

**Requirements**: macOS 12+ and Xcode 26 / Swift 6.2 (the package uses `swift-tools-version: 6.2`).

```bash
git clone https://github.com/BenjaminSRussell/3d-swift-globe-widget.git
cd 3d-swift-globe-widget

swift run TitanApp                                   # bundled sample network (9 hubs, 8 links)
TITAN_DATA=Tests/TitanCoreTests/Fixtures/sample_network.geojson swift run TitanApp   # your own GeoJSON
swift test                                           # unit tests (also run on Linux)
```

### Data (GeoJSON)

`GlobeDataLoader` reads a GeoJSON `FeatureCollection`:
- **`Point`** features are nodes. Properties: `id`, `name`, `intensity` (the number of server lights, default 10). Any other properties appear in the node detail panel.
- **`LineString`** features are links. Use `properties.from` and `properties.to` with node IDs, or start and end the line within 1 km of two nodes.
- Other geometry types are ignored.

The native `{"nodes": [...], "edges": [...]}` format also loads. Bad coordinates, duplicate IDs, and links to unknown nodes are rejected with a clear error. If `TITAN_DATA` fails to load, the app falls back to the bundled `Sources/TitanCore/Resources/default_network.geojson` and shows the error in the HUD.

### Configuration

`Configuration` (injected through `DependencyContainer`) controls:
- the default camera;
- **auto-fit**, which frames all loaded nodes on launch (on by default), with padding and min/max distance;
- arc animation length;
- light scatter.

Environment overrides:

| Variable | Effect |
|---|---|
| `TITAN_DATA` | Path to a GeoJSON or native dataset |
| `TITAN_BOOKMARKS` | Bookmarks file (default `~/Library/Application Support/TitanEngine/bookmarks.json`) |
| `TITAN_AUTOFIT` | `0` uses the configured camera instead of auto-fit |
| `TITAN_ARC_SECONDS` | Packet animation duration |

### Camera bookmarks

Use the **Bookmarks** menu in the top bar:
- **Save Current View** stores the camera centre, distance, pitch and heading.
- Picking a bookmark flies the camera back to it.
- **Delete** removes one.

Bookmarks are written to the bookmarks file right away, so they're still there after a relaunch. **Export Session…** writes one JSON file with the dataset and all bookmarks. **Import Session / GeoJSON…** restores a session, or loads a plain GeoJSON dataset.

### Layout

The HUD bars use `safeAreaInset` instead of fixed padding. The node detail panel, opened by clicking a hub, scrolls rather than clipping long IDs or property lists, and its width adapts between 220 and 340 pt.

## 🎮 Controls
- **Launch Packets**: Animates a packet along every link in the loaded dataset.
- **Click a hub**: Opens the node detail panel.
- **Map Interaction**: Full Zoom, Pan, Pitch, and Rotate support.

---
*Powered by TitanCore*
