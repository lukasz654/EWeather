struct SearchCitiesUseCase: Sendable {
    private let repository: any CitySearching

    init(repository: any CitySearching) {
        self.repository = repository
    }

    func execute(query: String) async throws -> [City] {
        try await repository.searchCities(named: query)
    }
}
