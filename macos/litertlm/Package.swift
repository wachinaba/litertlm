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
            url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.14.0/CLiteRTLM_mac.xcframework.zip?updated=20260710",
            checksum: "450615483509aaa6d34b321fdc6862e41a224b674468ab10aff64ebe113d21b7"
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