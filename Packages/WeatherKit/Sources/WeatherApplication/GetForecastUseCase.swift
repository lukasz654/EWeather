import WeatherDomain
import Foundation

public struct GetForecastUseCase: Sendable {
    private let repository: any ForecastProviding

    public init(repository: any ForecastProviding) {
        self.repository = repository
    }

    public func execute(city: City, range: HourlyForecastRange = .three) async throws -> Forecast? {
        try Task.checkCancellation()
        let result = try await repository.forecast(for: city, range: range)
        try Task.checkCancellation()
        guard let snapshot = result else { return nil }
        let hours = snapshot.hours
            .filter { $0.time > snapshot.updatedAt }
            .sorted { $0.time < $1.time }
            .prefix(range.rawValue)
        guard snapshot.temperature != nil || snapshot.cloudCover != nil || hours.contains(where: {
            $0.temperature != nil || $0.precipitationProbability != nil
        }) else { return nil }
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
