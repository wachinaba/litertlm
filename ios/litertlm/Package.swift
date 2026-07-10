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
            url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.14.0/CLiteRTLM.xcframework.zip?updated=20260710",
            checksum: "dddac2f6713ed65eaf01c18e115d9fec22184adf575cc7856a21387e8ba937e1"
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