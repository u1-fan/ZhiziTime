// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZhiziTime",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ZhiziTime", targets: ["ZhiziTime"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .executableTarget(
            name: "ZhiziTime",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/ZhiziTime",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("ZHIZI_ENABLE_SPARKLE", .when(configuration: .release))
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .testTarget(
            name: "ZhiziTimeTests",
            dependencies: ["ZhiziTime"],
            path: "tests/ZhiziTimeTests"
        )
    ]
)
