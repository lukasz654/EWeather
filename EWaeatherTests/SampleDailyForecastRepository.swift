@testable import EWaeather
import WeatherDomain
struct SampleDailyForecastRepository: DailyForecastProviding {
    func dailyForecast(for city: City) async throws -> [DailyForecast] {
        try Task.checkCancellation()
        return Self.days
    }

    static let days = [
        DailyForecast(day: ForecastDay(year: 2026, month: 11, day: 23)!, minimumTemperature: 2, maximumTemperature: 8, maximumPrecipitationProbability: 30, condition: .partlyCloudy),
        DailyForecast(day: ForecastDay(year: 2026, month: 11, day: 24)!, minimumTemperature: 1, maximumTemperature: 6, maximumPrecipitationProbability: 70, condition: .moderateRain),
        DailyForecast(day: ForecastDay(year: 2026, month: 11, day: 25)!, minimumTemperature: -1, maximumTemperature: 5, maximumPrecipitationProbability: 10, condition: .mainlyClear)
    ]
}
