// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WeatherKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WeatherDomain", targets: ["WeatherDomain"])
    ],
    targets: [
        .target(name: "WeatherDomain"),
        .testTarget(name: "WeatherDomainTests", dependencies: ["WeatherDomain"])
    ]
)
