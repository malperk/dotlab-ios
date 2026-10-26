// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DotLab",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DotLabCore", targets: ["DotLabCore"]),
        .executable(name: "dotbench", targets: ["DotBench"])
    ],
    targets: [
        .target(name: "DotLabCore"),
        .executableTarget(name: "DotBench", dependencies: ["DotLabCore"]),
        .testTarget(name: "DotLabCoreTests", dependencies: ["DotLabCore"])
    ]
)
