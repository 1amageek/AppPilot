// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppPilot",
    platforms: [.macOS(.v15)],
    products: [
        .library(
            name: "AppPilot",
            targets: ["AppPilot"])
    ],
    dependencies: [
        .package(url: "https://github.com/1amageek/AXUI.git", branch: "main")
    ],
    targets: [
        .target(
            name: "AppPilot",
            dependencies: ["AXUI"]
        ),
        .testTarget(
            name: "AppPilotTests",
            dependencies: [
                "AppPilot"
            ]
        ),
    ]
)
