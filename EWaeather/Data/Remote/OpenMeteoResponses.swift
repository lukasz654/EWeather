import Foundation

// Only Data knows the provider's JSON field names and array format.
struct GeocodingResponse: Decodable, Sendable {
    let results: [LocationResponse]?
}

struct LocationResponse: Decodable, Sendable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let admin1: String?
    let country: String?
    let timezone: String?
}

struct ForecastResponse: Decodable, Sendable {
    let timezone: String
    let current: CurrentResponse?
    let currentUnits: WeatherUnitsResponse?
    let hourly: HourlyResponse?
    let hourlyUnits: WeatherUnitsResponse?

    enum CodingKeys: String, CodingKey {
        case timezone, current, hourly
        case currentUnits = "current_units"
        case hourlyUnits = "hourly_units"
    }
}

struct CurrentResponse: Decodable, Sendable {
    let time: Double
    let temperature: Double?
    let cloudCover: Int?

    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case cloudCover = "cloud_cover"
    }
}

struct HourlyResponse: Decodable, Sendable {
    let time: [Double]
    let temperature: [Double?]?
    let precipitationProbability: [Int?]?

    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case precipitationProbability = "precipitation_probability"
    }
}

struct WeatherUnitsResponse: Decodable, Sendable {
    let time: String?
    let temperature: String?
    let cloudCover: String?
    let precipitationProbability: String?

    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case cloudCover = "cloud_cover"
        case precipitationProbability = "precipitation_probability"
    }
}
