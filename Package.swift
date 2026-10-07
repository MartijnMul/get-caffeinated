// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Caffeinated",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Caffeinated", path: "Sources/Caffeinated")
    ]
)
