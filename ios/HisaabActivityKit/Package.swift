// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "HisaabActivityKit",
  platforms: [
    .iOS(.v16),
  ],
  products: [
    .library(name: "HisaabActivityKit", targets: ["HisaabActivityKit"]),
  ],
  targets: [
    .target(
      name: "HisaabActivityKit",
      path: "Sources"
    ),
  ]
)
