// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CombinedApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CombinedApp",
            targets: ["CombinedApp"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CombinedApp",
            dependencies: [],
            path: "Sources"
        )
    ]
)
