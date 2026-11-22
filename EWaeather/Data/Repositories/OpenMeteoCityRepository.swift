struct OpenMeteoCityRepository: CitySearching {
    private let api: OpenMeteoAPI

    init(api: OpenMeteoAPI = OpenMeteoAPI()) {
        self.api = api
    }

    func searchCities(named query: String) async throws -> [City] {
        do {
            let response = try await api.searchCities(named: query)
            return try OpenMeteoMapper.cities(from: response)
        } catch let failure as HTTPFailure {
            throw failure.weatherFailure
        }
    }
}
