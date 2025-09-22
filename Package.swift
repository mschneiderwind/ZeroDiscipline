// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ZeroDiscipline",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "ZeroDiscipline",
            targets: ["ZeroDiscipline"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ZeroDisciplineLib",
            dependencies: []
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
