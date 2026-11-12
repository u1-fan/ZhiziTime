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
    targets: [
        .executableTarget(
            name: "ZhiziTime",
            path: "Sources/ZhiziTime"
        )
    ]
)
