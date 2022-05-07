// swift-tools-version: 5.6

import PackageDescription

let package = Package(
  name: "copilot-ios-actions",
  platforms: [
    .macOS(.v12),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    .package(url: "https://github.com/sergiocampama/APIBuilder.git", branch: "main"),
  ],
  targets: [
    .executableTarget(
      name: "copilot-action",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "APIBuilder", package: "APIBuilder"),
      ]
    ),
  ]
)
