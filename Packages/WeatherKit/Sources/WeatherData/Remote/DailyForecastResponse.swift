// Daily dates are date-only ISO strings in the forecast city's calendar.
struct DailyForecastResponse: Decodable, Sendable {
    let timezone: String
    let daily: DailyValuesResponse?
    let dailyUnits: DailyUnitsResponse?

    enum CodingKeys: String, CodingKey {
        case timezone, daily
        case dailyUnits = "daily_units"
    }
}

struct DailyValuesResponse: Decodable, Sendable {
    let time: [String]
    let minimumTemperature: [Double?]?
    let maximumTemperature: [Double?]?
    let maximumPrecipitationProbability: [Int?]?
    let weatherCode: [Int?]?

    enum CodingKeys: String, CodingKey {
        case time
        case minimumTemperature = "temperature_2m_min"
        case maximumTemperature = "temperature_2m_max"
        case maximumPrecipitationProbability = "precipitation_probability_max"
        case weatherCode = "weather_code"
    }
}

struct DailyUnitsResponse: Decodable, Sendable {
    let time: String?
    let minimumTemperature: String?
    let maximumTemperature: String?
    let maximumPrecipitationProbability: String?
    let weatherCode: String?

    enum CodingKeys: String, CodingKey {
        case time
        case minimumTemperature = "temperature_2m_min"
        case maximumTemperature = "temperature_2m_max"
        case maximumPrecipitationProbability = "precipitation_probability_max"
        case weatherCode = "weather_code"
    }
}
