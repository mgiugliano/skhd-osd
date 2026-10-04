// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "skhd-osd",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "skhd-osd", path: "Sources/skhd-osd")
    ]
)
