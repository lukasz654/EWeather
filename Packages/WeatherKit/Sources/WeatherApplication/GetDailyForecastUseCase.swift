import WeatherDomain

public struct GetDailyForecastUseCase: Sendable {
    private let repository: any DailyForecastProviding

    public init(repository: any DailyForecastProviding) {
        self.repository = repository
    }

    public func execute(city: City) async throws -> [DailyForecast] {
        try Task.checkCancellation()
        let days = try await repository.dailyForecast(for: city)
        try Task.checkCancellation()
        guard Set(days.map(\.id)).count == days.count else { throw WeatherFailure.invalidData }
        let selected = Array(days.sorted { $0.day < $1.day }.prefix(3))
        return selected.contains(where: \.hasWeatherData) ? selected : []
    }
}
