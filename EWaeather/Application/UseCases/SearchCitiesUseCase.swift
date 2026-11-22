import WeatherDomain
struct SearchCitiesUseCase: Sendable {
    private let repository: any CitySearching

    init(repository: any CitySearching) {
        self.repository = repository
    }

    func execute(query: String) async throws -> [City] {
        try Task.checkCancellation()
        guard let term = try CityQuery.searchTerm(query) else { return [] }
        let cities = try await repository.searchCities(named: term)
        try Task.checkCancellation()
        return cities
    }
}
