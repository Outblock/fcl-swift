// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FCL",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "FCL",
            targets: ["FCL"]
        ),
    ],
    dependencies: [
        .package(name: "Flow", url: "https://github.com/zed-io/flow-swift.git", from: "0.1.3-beta"),
    ],
    targets: [
        .target(
            name: "FCL",
            dependencies: ["Flow"],
            path: "Sources/FCL"
        ),
        .testTarget(
            name: "FCLTests",
            dependencies: ["FCL"],
            path: "Tests"
        ),
    ]
)
