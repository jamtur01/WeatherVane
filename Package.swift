// swift-tools-version: 6.0
import Foundation
import PackageDescription

let excludedSourceFiles = FileManager.default.fileExists(atPath: "Sources/CLAUDE.md")
    ? ["CLAUDE.md"]
    : []

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
            exclude: excludedSourceFiles
        ),
        .testTarget(
            name: "WeathervaneTests",
            dependencies: ["Weathervane"]
        )
    ]
)
