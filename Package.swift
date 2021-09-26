// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FCL",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "FCL",
            targets: ["FCL"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/zed-io/flow-swift.git", from: "0.0.3-beta"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "FCL",
            dependencies: [.product(name: "Flow", package: "flow-swift"),
                           .product(name: "AsyncHTTPClient", package: "async-http-client") ],
            path: "Sources/FCL"
        ),
        .testTarget(
            name: "FCLTests",
            dependencies: ["FCL", .product(name: "Flow", package: "flow-swift")],
            path: "Tests"
        ),
    ]
)
