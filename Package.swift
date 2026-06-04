// swift-tools-version:5.9
import PackageDescription

// PrimeEye - native macOS notch app. Pure Apple frameworks, ZERO third-party dependencies.
// Library target holds pure, unit-testable logic; executable holds AppKit glue.
let package = Package(
    name: "PrimeEye",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PrimeEyeKit"),
        .executableTarget(
            name: "PrimeEye",
            dependencies: ["PrimeEyeKit"]
        ),
        .testTarget(
            name: "PrimeEyeKitTests",
            dependencies: ["PrimeEyeKit"]
        ),
    ]
)
