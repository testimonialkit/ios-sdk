// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "TestimonialKit",
  platforms: [
    .iOS("16.0"),
    .macOS("13.0")
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "TestimonialKit",
      targets: ["TestimonialKit"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
    .package(url: "https://github.com/Charlyk/swift-theme-kit.git", branch: "fixAssets"),
    .package(url: "https://github.com/hmlongco/Factory.git", from: "2.5.3"),
    .package(url: "https://github.com/simibac/ConfettiSwiftUI.git", from: "2.0.3")
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    .target(
      name: "TestimonialKit",
      dependencies: [
        .product(name: "SwiftThemeKit", package: "swift-theme-kit"),
        .product(name: "Factory", package: "Factory"),
        .product(name: "ConfettiSwiftUI", package: "ConfettiSwiftUI")
      ],
      resources: [.process("Resources")],
      linkerSettings: [
        .linkedFramework("UIKit", .when(platforms: [.iOS, .macCatalyst])),
        .linkedFramework("AppKit", .when(platforms: [.macOS]))
      ]
    ),
  ]
)
