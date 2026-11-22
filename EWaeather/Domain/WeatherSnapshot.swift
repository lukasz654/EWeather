import Foundation

/// Provider-independent weather values before the app selects its forecast window.
struct WeatherSnapshot: Equatable, Sendable {
    let updatedAt: Date
    let timeZoneIdentifier: String
    let temperature: Double?
    let cloudCover: Int?
    let hours: [HourlyWeather]
}

struct HourlyWeather: Equatable, Sendable {
    let time: Date
    let temperature: Double?
    /// Probability for the hour ending at `time`, not an amount of rainfall.
    let precipitationProbability: Int?
}
