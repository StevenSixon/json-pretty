// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JSONPretty",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "JSONPretty",
            path: "Sources/JSONPretty"
        ),
        .testTarget(
            name: "JSONPrettyTests",
            dependencies: ["JSONPretty"],
            path: "Tests/JSONPrettyTests"
        )
    ]
)
