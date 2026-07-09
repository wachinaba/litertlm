// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "litertlm",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(name: "litertlm", targets: ["litertlm"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .binaryTarget(
            name: "CLiteRTLM",
            url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.14.0/CLiteRTLM.xcframework.zip",
            checksum: "4a4bdb0e89689ceacc54c2fb7ae0efe8f5dad2404110976a29c3bf6b374a511e"
        ),
        .target(
            name: "litertlm",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "CLiteRTLM",
            ],
            path: "Sources/litertlm"
        ),
    ]
)