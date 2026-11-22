// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WeatherKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WeatherDomain", targets: ["WeatherDomain"]),
        .library(name: "WeatherApplication", targets: ["WeatherApplication"])
    ],
    targets: [
        .target(name: "WeatherDomain"),
        .target(name: "WeatherApplication", dependencies: ["WeatherDomain"]),
        .testTarget(name: "WeatherDomainTests", dependencies: ["WeatherDomain"]),
        .testTarget(name: "WeatherApplicationTests", dependencies: ["WeatherApplication", "WeatherDomain"])
    ]
)
