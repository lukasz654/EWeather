import Foundation

struct Forecast: Equatable, Sendable {
    let updatedAt: Date
    let timeZoneIdentifier: String
    let temperature: Double?
    let cloudCover: Int?
    let precipitationProbability: Int?
    let precipitationInterval: DateInterval?
    let hours: [HourlyForecast]
}

struct HourlyForecast: Identifiable, Equatable, Sendable {
    var id: Date { time }
    let time: Date
    let temperature: Double?
}

enum WeatherFailure: Error, Equatable, Sendable {
    case offline
    case unavailable
    case invalidData
}
