import WeatherDomain
struct OpenMeteoForecastRepository: ForecastProviding {
    private let api: OpenMeteoAPI

    init(api: OpenMeteoAPI = OpenMeteoAPI()) {
        self.api = api
    }

    func forecast(for city: City) async throws -> WeatherSnapshot? {
        do {
            let response = try await api.forecast(latitude: city.latitude, longitude: city.longitude)
            return try OpenMeteoMapper.snapshot(from: response)
        } catch let failure as HTTPFailure {
            throw failure.weatherFailure
        }
    }
}
