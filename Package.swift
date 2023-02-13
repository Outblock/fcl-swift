// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FCL",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "FCL",
            targets: ["FCL"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/outblock/flow-swift.git", .exact("0.3.1")),
        .package(url: "https://github.com/daltoniam/Starscream", .exact("3.1.1")),
        .package(url: "https://github.com/WalletConnect/WalletConnectSwiftV2", .exact("1.0.6")),
        .package(url: "https://github.com/1024jp/GzipSwift", .exact("5.2.0")),
    ],
    targets: [
        .target(
            name: "FCL",
            dependencies: [
                .product(name: "Flow", package: "flow-swift"),
                .product(name: "Starscream", package: "Starscream"),
                .product(name: "WalletConnect", package: "WalletConnectSwiftV2"),
                .product(name: "WalletConnectAuth", package: "WalletConnectSwiftV2"),
                .product(name: "Gzip", package: "GzipSwift"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "FCLTests",
            dependencies: ["FCL"],
            path: "Tests"
        ),
    ]
)
