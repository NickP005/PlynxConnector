// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PlynxConnector",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "PlynxConnector",
            targets: ["PlynxConnector"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PlynxConnector",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "PlynxConnectorTests",
            dependencies: ["PlynxConnector"],
            path: "Tests"
        ),
    ]
)
