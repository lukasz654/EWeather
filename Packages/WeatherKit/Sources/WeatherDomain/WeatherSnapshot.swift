import Foundation

/// Provider-independent weather values before the app selects its forecast window.
public struct WeatherSnapshot: Equatable, Sendable {
    public let updatedAt: Date
    public let timeZoneIdentifier: String
    public let temperature: Double?
    public let cloudCover: Int?
    public let hours: [HourlyWeather]

    public init(updatedAt: Date, timeZoneIdentifier: String, temperature: Double?, cloudCover: Int?, hours: [HourlyWeather]) {
        self.updatedAt = updatedAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.temperature = temperature
        self.cloudCover = cloudCover
        self.hours = hours
    }
}

public struct HourlyWeather: Equatable, Sendable {
    public let time: Date
    public let temperature: Double?
    /// Probability for the hour ending at `time`, not an amount of rainfall.
    public let precipitationProbability: Int?

    public init(time: Date, temperature: Double?, precipitationProbability: Int?) {
        self.time = time
        self.temperature = temperature
        self.precipitationProbability = precipitationProbability
    }
}
