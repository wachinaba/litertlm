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
            url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.13.1/CLiteRTLM.xcframework.zip",
            checksum: "7ff01c42106b754748b5dd3036a4a57161b25ebf523e705bebc1219061852362"
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