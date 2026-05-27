// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipHist",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ClipHist", targets: ["ClipHist"]),
        .library(name: "ClipHistCore", targets: ["ClipHistCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ClipHistCore",
            path: "Sources/ClipHistCore"
        ),
        .executableTarget(
            name: "ClipHist",
            dependencies: ["ClipHistCore"],
            path: "Sources/ClipHist",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ClipHistCoreTests",
            dependencies: ["ClipHistCore"],
            path: "Tests/ClipHistCoreTests"
        ),
    ]
)
