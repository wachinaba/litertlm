// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "litertlm",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "litertlm", targets: ["litertlm"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .binaryTarget(
            name: "CLiteRTLM_mac",
            url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.13.1/CLiteRTLM_mac.xcframework.zip",
            checksum: "ec9ffe230dc39117a7fc8933b1cc15910454027fee6d3041534ab7cf17313981"
        ),
        .target(
            name: "litertlm",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "CLiteRTLM_mac",
            ],
            path: "Sources/litertlm"
        ),
    ]
)