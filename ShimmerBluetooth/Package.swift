// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "ShimmerBluetooth",
  platforms: [.macOS("15.0")],
  products: [
    .library(name: "ShimmerBluetooth", targets: ["ShimmerBluetooth"])
  ],
  targets: [
    .target(
      name: "ShimmerBluetooth",
      path: "ShimmerBluetooth",
      exclude: [
        // Objective-C umbrella header (not part of the Swift module)
        "ShimmerBluetooth.h",
        // DocC catalog is documentation, not source
        "ShimmerBluetooth.docc",
      ],
      // This is pre-existing CoreBluetooth code written against the Swift 5 concurrency
      // model; build it in the Swift 5 language mode so `swift build` resolves cleanly.
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    )
  ]
)
