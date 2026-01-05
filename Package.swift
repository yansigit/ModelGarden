// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ModelGarden",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "ModelGarden", targets: ["ModelGardenApp"]),
        .library(name: "ModelGardenKit", targets: ["ModelGardenKit"])
    ],
    dependencies: [
        // Remote dependency on mlx-swift-lm libraries (split from mlx-swift-examples)
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", branch: "main"),
        // Direct dependency for Hub/Transformers types (HubApi)
        .package(url: "https://github.com/huggingface/swift-transformers", .upToNextMinor(from: "1.1.0"))
    ],
    targets: [
        .target(
            name: "ModelGardenKit",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXVLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "Transformers", package: "swift-transformers")
            ],
            path: "Sources/ModelGardenKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "ModelGardenApp",
            dependencies: ["ModelGardenKit"],
            path: "Sources/ModelGardenApp",
            exclude: [
                "ModelGardenApp.entitlements"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
