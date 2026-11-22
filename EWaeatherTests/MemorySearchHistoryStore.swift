@testable import EWaeather
import WeatherDomain
@MainActor
final class MemorySearchHistoryStore: SearchHistoryReading, SearchHistoryWriting {
    private var cities: [City]

    init(cities: [City] = []) {
        self.cities = cities
    }

    func loadHistory() throws -> [City] { cities }

    func saveHistory(_ cities: [City]) throws { self.cities = cities }
}
