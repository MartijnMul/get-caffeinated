// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GetCaffeinated",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "GetCaffeinated", path: "Sources/GetCaffeinated"),
        .testTarget(name: "GetCaffeinatedTests", dependencies: ["GetCaffeinated"])
    ]
)
