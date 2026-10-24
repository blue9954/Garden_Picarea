// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GardenCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GardenCore", targets: ["GardenCore"]),
    ],
    targets: [
        .target(name: "GardenCore"),
        .testTarget(
            name: "GardenCoreTests",
            dependencies: ["GardenCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
