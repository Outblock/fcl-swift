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
        .package(url: "https://github.com/outblock/flow-swift.git", .exact("0.2.1")),
    ],
    targets: [
        .target(
            name: "FCL",
            dependencies: [.product(name: "Flow", package: "flow-swift")],
            path: "Sources/FCL"
        ),
        .testTarget(
            name: "FCLTests",
            dependencies: ["FCL"],
            path: "Tests"
        ),
    ]
)
