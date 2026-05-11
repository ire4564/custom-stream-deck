// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StreamDec",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "StreamDec", targets: ["StreamDec"])
    ],
    targets: [
        .executableTarget(
            name: "StreamDec",
            path: "StreamDec",
            exclude: ["Resources/Info.plist"],
            resources: [
                .process("Resources/Assets")
            ]
        )
    ]
)
