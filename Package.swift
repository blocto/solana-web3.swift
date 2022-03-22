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
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .upToNextMajor(from: "1.4.3")),
        .package(name: "TweetNacl", url: "https://github.com/bitmark-inc/tweetnacl-swiftwrap.git", from: "1.1.0"),
        .package(url: "https://github.com/wickwirew/Runtime.git", from: "2.2.2")
    ],
    targets: [
        .target(
            name: "SolanaWeb3",
            dependencies: ["CryptoSwift", "TweetNacl", "Runtime"]
        ),
        .testTarget(
            name: "SolanaWeb3Tests",
            dependencies: ["SolanaWeb3"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
