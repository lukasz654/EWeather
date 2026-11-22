import WeatherDomain
public struct OpenMeteoCityRepository: CitySearching {
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

    public func searchCities(named query: String) async throws -> [City] {
        do {
            let response = try await api.searchCities(named: query)
            return try OpenMeteoMapper.cities(from: response)
        } catch let failure as HTTPFailure {
            throw failure.weatherFailure
        }
    }
}
