// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Soundbar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Soundbar", targets: ["Soundbar"])
    ],
    targets: [
        .target(
            name: "SoundbarCore",
            path: "Sources/SoundbarCore"
        ),
        .executableTarget(
            name: "Soundbar",
            dependencies: ["SoundbarCore"],
            path: "Sources/Soundbar"
        ),
        .testTarget(
            name: "SoundbarTests",
            dependencies: ["SoundbarCore"],
            path: "Tests/SoundbarTests"
        )
    ]
)
