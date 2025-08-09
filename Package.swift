// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "TestimonialKit",
  platforms: [
    .iOS("15.0") // ✅ specify the minimum iOS version
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "TestimonialKit",
      targets: ["TestimonialKit"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/Charlyk/swift-theme-kit.git", from: "1.0.4"),
    .package(url: "https://github.com/hmlongco/Factory.git", from: "2.5.3")
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    .target(
      name: "TestimonialKit",
      dependencies: [
        .product(name: "SwiftThemeKit", package: "swift-theme-kit"),
        .product(name: "Factory", package: "Factory")
      ],
      resources: [.process("Resources")],
      linkerSettings: [
        .linkedFramework("UIKit"),
        .linkedFramework("SwiftUI"),
        .linkedFramework("Combine")
      ]
    ),
  ]
)
