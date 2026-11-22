import Foundation

enum OpenMeteoMapper {
    static func cities(from response: GeocodingResponse) throws -> [City] {
        try (response.results ?? []).map { location in
            guard !location.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (-90...90).contains(location.latitude), (-180...180).contains(location.longitude) else {
                throw WeatherFailure.invalidData
            }
            return City(
                id: location.id, name: location.name, region: location.admin1, country: location.country,
                latitude: location.latitude, longitude: location.longitude,
                // Search rows do not show time. Forecasts use their own authoritative time zone.
                timeZoneIdentifier: location.timezone ?? "GMT"
            )
        }
    }

    static func snapshot(from response: ForecastResponse) throws -> WeatherSnapshot? {
        guard TimeZone(identifier: response.timezone) != nil else { throw WeatherFailure.invalidData }
        guard let current = response.current else {
            guard response.hourly?.time.isEmpty != false else { throw WeatherFailure.invalidData }
            return nil
        }
        guard response.currentUnits?.time == "unixtime",
              response.currentUnits?.temperature == "°C", response.currentUnits?.cloudCover == "%",
              current.time.isFinite, current.temperature?.isFinite != false,
              validPercent(current.cloudCover) else { throw WeatherFailure.invalidData }

        let hours = try hourlyWeather(from: response)
        guard current.temperature != nil || current.cloudCover != nil || hours.contains(where: {
            $0.temperature != nil || $0.precipitationProbability != nil
        }) else { return nil }

        return WeatherSnapshot(
            updatedAt: Date(timeIntervalSince1970: current.time), timeZoneIdentifier: response.timezone,
            temperature: current.temperature, cloudCover: current.cloudCover, hours: hours
        )
    }

    private static func hourlyWeather(from response: ForecastResponse) throws -> [HourlyWeather] {
        guard let hourly = response.hourly else { return [] }
        guard response.hourlyUnits?.time == "unixtime",
              response.hourlyUnits?.temperature == "°C", response.hourlyUnits?.precipitationProbability == "%",
              hourly.temperature.map({ $0.count == hourly.time.count }) ?? true,
              hourly.precipitationProbability.map({ $0.count == hourly.time.count }) ?? true else {
            throw WeatherFailure.invalidData
        }
        // Reject mismatched arrays or duplicate times instead of attaching values to the wrong hour.
        return try hourly.time.indices.map { index in
            let time = hourly.time[index]
            let temperature = hourly.temperature?[index]
            let probability = hourly.precipitationProbability?[index]
            guard time.isFinite, index == 0 || time > hourly.time[index - 1],
                  temperature?.isFinite != false, validPercent(probability) else {
                throw WeatherFailure.invalidData
            }
            return HourlyWeather(time: Date(timeIntervalSince1970: time), temperature: temperature, precipitationProbability: probability)
        }
    }

    private static func validPercent(_ value: Int?) -> Bool {
        value.map { (0...100).contains($0) } ?? true
    }
}
