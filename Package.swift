// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoiceInputApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VoiceInputApp", targets: ["VoiceInputApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.12.4")
    ],
    targets: [
        .executableTarget(
            name: "VoiceInputApp",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
            path: "Sources/VoiceInputApp",
            exclude: ["Resources/Info.plist"],
            resources: [
                .copy("Resources/AuthorWeChatQRCode.jpg"),
                .copy("Resources/GitHubMark.png")
            ]
        ),
        .testTarget(
            name: "VoiceInputAppTests",
            dependencies: ["VoiceInputApp"]
        )
    ]
)
