// swift-tools-version: 6.0
import PackageDescription

/// Platform-neutral models and PDF/image services shared by the macOS app and a future iOS app.
/// Nothing here may import AppKit or UIKit.
let package = Package(
    name: "BeaverCore",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "BeaverCore", targets: ["BeaverCore"])
    ],
    targets: [
        .target(
            name: "BeaverCore",
            resources: [.process("Resources")]
        )
    ]
)
