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
        )
    ],
    dependencies: [
        .package(name: "Flow", url: "https://github.com/zed-io/flow-swift.git", .revision("0b0b706039a7c8b7ef21bc159e06ace5df60b6c4"))
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
        )
    ]
)
