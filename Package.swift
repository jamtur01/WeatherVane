// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Weathervane",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Weathervane",
            targets: ["Weathervane"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Weathervane",
            dependencies: [],
            path: "Sources"
        )
    ]
)
