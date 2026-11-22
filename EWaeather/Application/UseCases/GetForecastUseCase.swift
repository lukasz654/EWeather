import Foundation

struct GetForecastUseCase: Sendable {
    private let repository: any ForecastProviding

    init(repository: any ForecastProviding) {
        self.repository = repository
    }

    func execute(city: City) async throws -> Forecast? {
        guard let snapshot = try await repository.forecast(for: city) else { return nil }
        try Task.checkCancellation()
        let hours = snapshot.hours
            .filter { $0.time > snapshot.updatedAt }
            .sorted { $0.time < $1.time }
            .prefix(24)
        let rainHour = hours.first
        return Forecast(
            updatedAt: snapshot.updatedAt,
            timeZoneIdentifier: snapshot.timeZoneIdentifier,
            temperature: snapshot.temperature,
            cloudCover: snapshot.cloudCover,
            precipitationProbability: rainHour?.precipitationProbability,
            precipitationInterval: rainHour.map { DateInterval(start: $0.time.addingTimeInterval(-3600), end: $0.time) },
            hours: hours.map { HourlyForecast(time: $0.time, temperature: $0.temperature) }
        )
    }
}
