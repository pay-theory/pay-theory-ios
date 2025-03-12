// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PayTheory",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PayTheory",
            targets: ["PayTheory"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jedisct1/swift-sodium.git", exact: "0.9.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "PayTheory",
            dependencies: [.product(name: "Sodium", package: "swift-sodium")],
            path: "Sources/pay-theory-ios",
            swiftSettings: [
                    .define("iOS", .when(platforms: [.iOS]))
                ]
        ),
        .testTarget(
            name: "pay-theory-iosTests",
            dependencies: ["PayTheory"]),
    ]
)
