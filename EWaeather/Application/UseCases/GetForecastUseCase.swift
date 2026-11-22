struct GetForecastUseCase: Sendable {
    private let repository: any ForecastProviding

    init(repository: any ForecastProviding) {
        self.repository = repository
    }

    func execute(city: City) async throws -> Forecast? {
        try await repository.forecast(for: city)
    }
}
