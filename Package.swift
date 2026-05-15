// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "hyprmon",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "hyprmon", targets: ["hyprmon"]),
        .library(name: "HyprmonCore", targets: ["HyprmonCore"]),
    ],
    targets: [
        .target(
            name: "HyprmonCore",
            path: "Sources/HyprmonCore"
        ),
        .executableTarget(
            name: "hyprmon",
            dependencies: ["HyprmonCore"],
            path: "Sources/hyprmon"
        ),
        .testTarget(
            name: "HyprmonCoreTests",
            dependencies: ["HyprmonCore"],
            path: "Tests/HyprmonCoreTests"
        ),
    ]
)
