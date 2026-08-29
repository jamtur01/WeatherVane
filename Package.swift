// swift-tools-version: 6.0
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
            path: "Sources",
            exclude: ["CLAUDE.md"]
        ),
        .testTarget(
            name: "WeathervaneTests",
            dependencies: ["Weathervane"]
        )
    ]
)
