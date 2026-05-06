// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "WallhavenMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "WallhavenCore", targets: ["WallhavenCore"]),
        .executable(name: "WallhavenMac", targets: ["WallhavenMac"])
    ],
    targets: [
        .target(name: "WallhavenCore"),
        .executableTarget(
            name: "WallhavenMac",
            dependencies: ["WallhavenCore"]
        ),
        .testTarget(
            name: "WallhavenCoreTests",
            dependencies: ["WallhavenCore"],
            swiftSettings: [
                .unsafeFlags([
                    "-F",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ])
            ]
        )
    ]
)
