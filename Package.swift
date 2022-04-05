// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SolanaWeb3",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v11),
        .tvOS(.v11),
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
        .package(url: "https://github.com/wickwirew/Runtime.git", from: "2.2.2"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.5.0")),
        .package(url: "https://github.com/WeTransfer/Mocker.git", .upToNextMajor(from: "2.3.0"))
    ],
    targets: [
        .target(
            name: "SolanaWeb3",
            dependencies: ["CryptoSwift", "TweetNacl", "Runtime", "Alamofire"]
        ),
        .testTarget(
            name: "SolanaWeb3Tests",
            dependencies: ["SolanaWeb3", "Mocker"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
