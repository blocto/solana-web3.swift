// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SolanaWeb3",
    platforms: [
        .macOS(.v10_12),
        .iOS(.v10),
        .tvOS(.v10),
        .watchOS(.v3)
    ],
    products: [
        .library(
            name: "SolanaWeb3",
            targets: ["SolanaWeb3"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SolanaWeb3",
            resources: [ .process("Resources") ]
        ),
        .testTarget(
            name: "SolanaWeb3Tests",
            resources: [ .process("Resources") ]
        ),
    ]
)
