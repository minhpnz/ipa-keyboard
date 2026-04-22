// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "IPACore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "IPACore", targets: ["IPACore"]),
    ],
    targets: [
        .target(name: "IPACore", path: "Sources/IPACore"),
        .testTarget(
            name: "IPACoreTests",
            dependencies: ["IPACore"],
            path: "Tests/IPACoreTests"
        ),
    ]
)
