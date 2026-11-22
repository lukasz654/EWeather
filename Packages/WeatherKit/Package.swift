// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WeatherKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WeatherDomain", targets: ["WeatherDomain"]),
        .library(name: "WeatherApplication", targets: ["WeatherApplication"]),
        .library(name: "WeatherData", targets: ["WeatherData"])
    ],
    targets: [
        .target(name: "WeatherDomain"),
        .target(name: "WeatherApplication", dependencies: ["WeatherDomain"]),
        .target(name: "WeatherData", dependencies: ["WeatherDomain"]),
        .testTarget(name: "WeatherDomainTests", dependencies: ["WeatherDomain"]),
        .testTarget(name: "WeatherApplicationTests", dependencies: ["WeatherApplication", "WeatherDomain"]),
        .testTarget(name: "WeatherDataTests", dependencies: ["WeatherData", "WeatherDomain"])
    ]
)
