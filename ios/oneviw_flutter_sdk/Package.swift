// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "oneviw_flutter_sdk",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "oneviw-flutter-sdk", targets: ["oneviw_flutter_sdk"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "oneviw_flutter_sdk",
            dependencies: []
        )
    ]
)
