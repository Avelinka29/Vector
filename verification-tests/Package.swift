// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DocumentVerificationChecks",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DocumentVerificationCore"),
        .testTarget(name: "DocumentVerificationCoreTests", dependencies: ["DocumentVerificationCore"])
    ]
)
