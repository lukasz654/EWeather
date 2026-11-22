import Foundation

struct OpenMeteoAPI: Sendable {
    private let client: HTTPClient

    init(client: HTTPClient = HTTPClient()) {
        self.client = client
    }

    func searchCities(named query: String) async throws -> GeocodingResponse {
        let url = try endpoint(host: "geocoding-api.open-meteo.com", path: "/v1/search", items: [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "10"),
            URLQueryItem(name: "language", value: "pl"),
            URLQueryItem(name: "format", value: "json")
        ])
        return try await client.get(url, as: GeocodingResponse.self)
    }

    func forecast(latitude: Double, longitude: Double) async throws -> ForecastResponse {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw WeatherFailure.invalidData
        }
        let url = try endpoint(host: "api.open-meteo.com", path: "/v1/forecast", items: [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,cloud_cover"),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability"),
            URLQueryItem(name: "forecast_hours", value: "25"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime")
        ])
        return try await client.get(url, as: ForecastResponse.self)
    }

    private func endpoint(host: String, path: String, items: [URLQueryItem]) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = items
        guard let url = components.url else { throw WeatherFailure.invalidData }
        return url
    }
}
