// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LLMUsageBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LLMUsageBar", targets: ["LLMUsageBar"])
    ],
    targets: [
        .executableTarget(
            name: "LLMUsageBar",
            path: "Sources/LLMUsageBar",
            exclude: [
                "Resources/ProviderLogos/aliyun-bailian.png",
                "Resources/ProviderLogos/aliyun-cloud.png"
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
