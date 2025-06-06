// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppPilot",
    platforms: [.macOS(.v15)],
    products: [
        .library(
            name: "AppPilot",
            targets: ["AppPilot"]),
        .executable(
            name: "BasicUsage",
            targets: ["BasicUsage"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "AppPilot"),
        .executableTarget(
            name: "BasicUsage",
            dependencies: ["AppPilot"],
            path: "Examples"),
        .testTarget(
            name: "AppPilotTests",
            dependencies: [
                "AppPilot"
            ]
        ),
    ]
)
