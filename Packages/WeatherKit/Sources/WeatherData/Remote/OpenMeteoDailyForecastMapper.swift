import Foundation
import WeatherDomain

enum OpenMeteoDailyForecastMapper {
    static func days(from response: DailyForecastResponse) throws -> [DailyForecast] {
        guard TimeZone(identifier: response.timezone) != nil else { throw WeatherFailure.invalidData }
        guard let daily = response.daily, !daily.time.isEmpty else { return [] }
        guard response.dailyUnits?.time == "iso8601",
              response.dailyUnits?.minimumTemperature == "°C",
              response.dailyUnits?.maximumTemperature == "°C",
              response.dailyUnits?.maximumPrecipitationProbability == "%",
              response.dailyUnits?.weatherCode?.lowercased() == "wmo code",
              [daily.minimumTemperature?.count, daily.maximumTemperature?.count,
               daily.maximumPrecipitationProbability?.count, daily.weatherCode?.count]
                .allSatisfy({ $0 == nil || $0 == daily.time.count }) else {
            throw WeatherFailure.invalidData
        }
        var previous: ForecastDay?
        return try daily.time.indices.map { index in
            let day = try calendarDay(daily.time[index])
            guard previous.map({ day > $0 }) ?? true else { throw WeatherFailure.invalidData }
            previous = day
            let minimum = daily.minimumTemperature?[index]
            let maximum = daily.maximumTemperature?[index]
            let probability = daily.maximumPrecipitationProbability?[index]
            guard minimum?.isFinite != false, maximum?.isFinite != false,
                  probability.map({ (0...100).contains($0) }) ?? true else {
                throw WeatherFailure.invalidData
            }
            if let minimum, let maximum, minimum > maximum { throw WeatherFailure.invalidData }
            return DailyForecast(
                day: day, minimumTemperature: minimum, maximumTemperature: maximum,
                maximumPrecipitationProbability: probability,
                condition: condition(for: daily.weatherCode?[index])
            )
        }
    }

    private static func calendarDay(_ text: String) throws -> ForecastDay {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].utf8.count == 4, parts[1].utf8.count == 2, parts[2].utf8.count == 2,
              parts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              let result = ForecastDay(year: year, month: month, day: day) else {
            throw WeatherFailure.invalidData
        }
        return result
    }

    private static func condition(for code: Int?) -> DailyWeatherCondition {
        switch code {
        case 0: .clearSky
        case 1: .mainlyClear
        case 2: .partlyCloudy
        case 3: .overcast
        case 45: .fog
        case 48: .rimeFog
        case 51: .lightDrizzle
        case 53: .moderateDrizzle
        case 55: .denseDrizzle
        case 56: .lightFreezingDrizzle
        case 57: .denseFreezingDrizzle
        case 61: .lightRain
        case 63: .moderateRain
        case 65: .heavyRain
        case 66: .lightFreezingRain
        case 67: .heavyFreezingRain
        case 71: .lightSnow
        case 73: .moderateSnow
        case 75: .heavySnow
        case 77: .snowGrains
        case 80: .lightRainShowers
        case 81: .moderateRainShowers
        case 82: .violentRainShowers
        case 85: .lightSnowShowers
        case 86: .heavySnowShowers
        case 95: .thunderstorm
        case 96: .thunderstormWithLightHail
        case 97: .heavyThunderstorm
        case 99: .thunderstormWithHeavyHail
        default: .unknown
        }
    }
}
