public protocol DailyForecastProviding: Sendable {
    /// Returns local calendar days from the forecast city's current day.
    /// Missing results are empty; cancellation must remain cancellation.
    func dailyForecast(for city: City) async throws -> [DailyForecast]
}
