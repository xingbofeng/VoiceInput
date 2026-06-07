// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceInputApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VoiceInputApp", targets: ["VoiceInputApp"])
    ],
    targets: [
        .executableTarget(
            name: "VoiceInputApp",
            path: "Sources/VoiceInputApp",
            exclude: ["Resources/Info.plist"]
        ),
        .testTarget(
            name: "VoiceInputAppTests",
            dependencies: ["VoiceInputApp"]
        )
    ]
)
