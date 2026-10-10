// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GridZeroCore",
    platforms: [.iOS("26.0"), .macOS(.v15)],
    products: [.library(name: "GridZeroCore", targets: ["GridZeroCore"])],
    targets: [
        .target(name: "GridZeroCore", resources: [.process("Resources")]),
        .testTarget(name: "GridZeroCoreTests", dependencies: ["GridZeroCore"], resources: [.process("Resources")])
    ]
)
