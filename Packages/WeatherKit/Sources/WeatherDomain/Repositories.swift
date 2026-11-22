public protocol CitySearching: Sendable {
    func searchCities(named query: String) async throws -> [City]
}

public protocol ForecastProviding: Sendable {
    func forecast(for city: City) async throws -> WeatherSnapshot?
}
