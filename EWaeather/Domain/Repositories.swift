protocol CitySearching: Sendable {
    func searchCities(named query: String) async throws -> [City]
}

protocol ForecastProviding: Sendable {
    func forecast(for city: City) async throws -> WeatherSnapshot?
}
