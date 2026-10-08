// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TitanEngine",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "TitanCore",
            targets: ["TitanCore"]
        )
    ],
    targets: [
        .target(
            name: "TitanCore",
            dependencies: [],
            path: "Sources/TitanCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "TitanCoreTests",
            dependencies: ["TitanCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)

// The SwiftUI/MapKit demo app only exists on macOS. TitanCore's data, geometry, config and
// bookmark code (and its tests) also build on Linux; the MapKit views are `#if canImport(MapKit)`.
#if os(macOS)
package.products.append(.executable(name: "TitanApp", targets: ["TitanApp"]))
package.targets.append(.executableTarget(name: "TitanApp", dependencies: ["TitanCore"], path: "Sources/TitanApp"))
#endif
