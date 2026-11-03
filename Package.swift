// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Edge",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Edge",
            targets: ["Edge"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Edge",
            dependencies: [],
            path: "Sources/Edge",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox")
            ]
        ),
        .testTarget(
            name: "EdgeTests",
            dependencies: ["Edge"],
            path: "Tests/EdgeTests",
            swiftSettings: [
                .unsafeFlags([
                    "-load-plugin-library",
                    "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
                ])
            ]
        )
    ]
)
