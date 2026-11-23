@testable import EWaeather
import WeatherDomain
import Foundation

/// Local fixtures for stage 1. These values are not weather observations or API responses.
struct SampleWeatherRepository: CitySearching, ForecastProviding {
    func searchCities(named query: String) async throws -> [City] {
        try Task.checkCancellation()
        return Self.cities.filter {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
                .contains(query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL")))
        }
    }

    func forecast(for city: City, range: HourlyForecastRange) async throws -> WeatherSnapshot? {
        try Task.checkCancellation()
        return Self.snapshot(timeZoneIdentifier: city.timeZoneIdentifier, range: range)
    }

    static let cities: [City] = [
        City(id: 1, name: "Bielsko-Biała", region: "Śląskie", country: "Polska", latitude: 49.82, longitude: 19.04, timeZoneIdentifier: "Europe/Warsaw"),
        City(id: 2, name: "Nowy Sącz", region: "Małopolskie", country: "Polska", latitude: 49.62, longitude: 20.70, timeZoneIdentifier: "Europe/Warsaw"),
        City(id: 3, name: "Warszawa", region: "Mazowieckie", country: "Polska", latitude: 52.23, longitude: 21.01, timeZoneIdentifier: "Europe/Warsaw")
    ]

    static func forecast(timeZoneIdentifier: String = "Europe/Warsaw", range: HourlyForecastRange = .three) -> Forecast {
        let start = Date(timeIntervalSince1970: 1_795_352_400)
        let temperatures: [Double] = [8, 8, 7, 7, 6, 6, 5, 5, 5, 6, 7, 8, 9, 10, 11, 11, 10, 9, 9, 8, 8, 7, 7, 6]
        return Forecast(
            updatedAt: start,
            timeZoneIdentifier: timeZoneIdentifier,
            temperature: 8,
            cloudCover: 65,
            precipitationProbability: 30,
            precipitationInterval: DateInterval(start: start, duration: 3600),
            hours: temperatures.prefix(range.rawValue).enumerated().map { index, temperature in
                HourlyForecast(time: start.addingTimeInterval(Double(index + 1) * 3600), temperature: temperature)
            }
        )
    }

    static func snapshot(timeZoneIdentifier: String = "Europe/Warsaw", range: HourlyForecastRange = .three) -> WeatherSnapshot {
        let forecast = Self.forecast(timeZoneIdentifier: timeZoneIdentifier, range: range)
        return WeatherSnapshot(
            updatedAt: forecast.updatedAt,
            timeZoneIdentifier: forecast.timeZoneIdentifier,
            temperature: forecast.temperature,
            cloudCover: forecast.cloudCover,
            hours: forecast.hours.map {
                HourlyWeather(time: $0.time, temperature: $0.temperature, precipitationProbability: forecast.precipitationProbability)
            }
        )
    }
}
