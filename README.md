# 3D Swift Globe Widget

A Swift package that provides an interactive 3D globe widget for iOS and macOS applications with geospatial location support.

## Features

- **Interactive 3D Globe**: A rotating Earth globe using SceneKit
- **Touch/Mouse Controls**: Built-in camera controls for zooming and rotating
- **Geospatial Support**: Add location pins to specific coordinates
- **SwiftUI Integration**: Easy to use in any SwiftUI view
- **Cross-Platform**: Works on iOS 15+ and macOS 12+

## Installation

Add this package to your Swift project using Xcode or Swift Package Manager.

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/BenjaminSRussell/3d-swift-globe-widget.git", from: "1.0.0")
]
```

## Usage

### Basic Usage

```swift
import SwiftUI
import Globe3DWidget

struct ContentView: View {
    var body: some View {
        Globe3DWidget()
            .frame(width: 300, height: 300)
    }
}
```

### Adding Location Pins

```swift
struct ContentView: View {
    let locations = [
        GeoLocation(latitude: 40.7128, longitude: -74.0060, name: "New York"),
        GeoLocation(latitude: 51.5074, longitude: -0.1278, name: "London"),
        GeoLocation(latitude: 35.6762, longitude: 139.6503, name: "Tokyo")
    ]
    
    var body: some View {
        Globe3DWidget()
            .frame(width: 300, height: 300)
            .onAppear {
                // Add location pins (implementation in progress)
                for location in locations {
                    // globe.addLocationPin(at: location)
                }
            }
    }
}
```

### Controlling Rotation

```swift
Globe3DWidget()
    .stopRotation() // or .startRotation()
```

## Requirements

- iOS 15.0+ / macOS 12.0+
- Xcode 13.0+
- Swift 5.6+

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
