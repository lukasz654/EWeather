import WeatherDomain
public struct OpenMeteoForecastRepository: ForecastProviding {
    private let api: OpenMeteoAPI

    public init() {
        self.api = OpenMeteoAPI()
    }

    public init(transport: any HTTPTransport) {
        self.api = OpenMeteoAPI(client: HTTPClient(transport: transport))
    }

    init(api: OpenMeteoAPI) {
        self.api = api
    }

    public func forecast(for city: City, range: HourlyForecastRange) async throws -> WeatherSnapshot? {
        do {
            let response = try await api.forecast(latitude: city.latitude, longitude: city.longitude, hourCount: range.rawValue + 1)
            return try OpenMeteoMapper.snapshot(from: response)
        } catch let failure as HTTPFailure {
            throw failure.weatherFailure
        }
    }
}
