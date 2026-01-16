// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "3d-swift-globe-widget",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "3d-swift-globe-widget",
            targets: ["3d-swift-globe-widget"]
        ),
        .executable(
            name: "GlobeDemo",
            targets: ["GlobeDemo"]
        )
    ],
    targets: [
        .target(
            name: "3d-swift-globe-widget",
            dependencies: []
        ),
        .executableTarget(
            name: "GlobeDemo",
            dependencies: ["3d-swift-globe-widget"],
            path: "Sources/GlobeDemo"
        ),
        .testTarget(
            name: "3d-swift-globe-widgetTests",
            dependencies: ["3d-swift-globe-widget"]
        ),
    ]
)
