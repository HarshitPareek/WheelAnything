// swift-tools-version: 6.0
// Tools version 6.0 also turns on Swift 6 language mode, which includes
// strict concurrency checking (CLAUDE.md §3).

import PackageDescription

let package = Package(
    name: "WheelCore",
    // Matches the app's deployment target (PLAN.md §2).
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WheelCore", targets: ["WheelCore"])
    ],
    targets: [
        .target(name: "WheelCore"),
        // Fixtures/ holds small sample files; .copy keeps the folder as-is in the test bundle.
        .testTarget(name: "WheelCoreTests", dependencies: ["WheelCore"], resources: [.copy("Fixtures")]),
    ]
)
