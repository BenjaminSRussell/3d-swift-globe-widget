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
        ),
        .executable(
            name: "TitanApp", // Renamed from TitanDemo
            targets: ["TitanApp"]
        )
    ],
    targets: [
        .target(
            name: "TitanCore",
            dependencies: [],
            path: "Sources/TitanCore",
            resources: [] 
        ),
        .executableTarget(
            name: "TitanApp", // Renamed from TitanDemo
            dependencies: ["TitanCore"],
            path: "Sources/TitanApp"
        ),
        .testTarget(
            name: "TitanCoreTests",
            dependencies: ["TitanCore"]
        )
    ]
)
