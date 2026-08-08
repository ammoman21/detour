// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Detour",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Detour",
            path: "Sources/Detour"
        )
    ]
)
