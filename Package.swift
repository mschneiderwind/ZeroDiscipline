// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZeroDiscipline",
    platforms: [.macOS(.v15)],
    products: [
        .executable(
            name: "ZeroDiscipline",
            targets: ["ZeroDiscipline"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.2")
    ],
    targets: [
        .target(
            name: "ZeroDisciplineLib",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .executableTarget(
            name: "ZeroDiscipline",
            dependencies: ["ZeroDisciplineLib"]
        ),
        .testTarget(
            name: "ZeroDisciplineTests",
            dependencies: ["ZeroDisciplineLib"]
        ),
    ]
)
