import WeatherDomain

public struct OpenMeteoDailyForecastRepository: DailyForecastProviding {
    private let api: OpenMeteoAPI

    public init() {
        api = OpenMeteoAPI()
    }

    public init(transport: any HTTPTransport) {
        api = OpenMeteoAPI(client: HTTPClient(transport: transport))
    }

    public func dailyForecast(for city: City) async throws -> [DailyForecast] {
        do {
            let response = try await api.dailyForecast(latitude: city.latitude, longitude: city.longitude)
            return try OpenMeteoDailyForecastMapper.days(from: response)
        } catch let failure as HTTPFailure {
            throw failure.weatherFailure
        }
    }
}
