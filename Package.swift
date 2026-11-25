// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GetCaffeinated",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GetCaffeinated",
            dependencies: ["LidAwakeShared"],
            path: "Sources/GetCaffeinated"
        ),
        // The root daemon behind "Awake with lid closed", bundled inside the app.
        .executableTarget(
            name: "GetCaffeinatedHelper",
            dependencies: ["LidAwakeShared"],
            path: "Sources/GetCaffeinatedHelper"
        ),
        .target(name: "LidAwakeShared", path: "Sources/LidAwakeShared"),
        .testTarget(name: "GetCaffeinatedTests", dependencies: ["GetCaffeinated"])
    ]
)
