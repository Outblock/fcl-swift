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
        .package(name: "Flow",
                 url: "https://github.com/outblock/flow-swift.git",
                 .revision("fcd6915f59c1847e372b358fdf9e5d1e0a0fe639")),
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
