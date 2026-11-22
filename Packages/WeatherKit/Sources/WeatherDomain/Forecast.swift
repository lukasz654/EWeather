import Foundation

public struct Forecast: Equatable, Sendable {
    public let updatedAt: Date
    public let timeZoneIdentifier: String
    public let temperature: Double?
    public let cloudCover: Int?
    public let precipitationProbability: Int?
    public let precipitationInterval: DateInterval?
    public let hours: [HourlyForecast]

    public init(updatedAt: Date, timeZoneIdentifier: String, temperature: Double?, cloudCover: Int?, precipitationProbability: Int?, precipitationInterval: DateInterval?, hours: [HourlyForecast]) {
        self.updatedAt = updatedAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.temperature = temperature
        self.cloudCover = cloudCover
        self.precipitationProbability = precipitationProbability
        self.precipitationInterval = precipitationInterval
        self.hours = hours
    }
}

public struct HourlyForecast: Identifiable, Equatable, Sendable {
    public var id: Date { time }
    public let time: Date
    public let temperature: Double?

    public init(time: Date, temperature: Double?) {
        self.time = time
        self.temperature = temperature
    }
}

public enum WeatherFailure: Error, Equatable, Sendable {
    case offline
    case unavailable
    case invalidData
}
