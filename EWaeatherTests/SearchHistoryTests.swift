import WeatherData
import WeatherApplication
import WeatherDomain
import XCTest
@testable import EWaeather

@MainActor
final class SearchHistoryTests: XCTestCase {
    private let cities = SampleWeatherRepository.cities

    func testRecreatedStorageRestoresCityIdentityCoordinatesAndOrder() throws {
        try withDefaults { defaults in
            let firstStore = UserDefaultsSearchHistoryStore(defaults: defaults)
            let remember = RememberCityUseCase(reader: firstStore, writer: firstStore)
            _ = try remember.execute(city: cities[0])
            _ = try remember.execute(city: cities[1])

            let recreatedStore = UserDefaultsSearchHistoryStore(defaults: defaults)
            XCTAssertEqual(try LoadSearchHistoryUseCase(repository: recreatedStore).execute(), [cities[1], cities[0]])
        }
    }

    func testCorruptedHistoryIsReportedAndNotOverwritten() throws {
        try withDefaults { defaults in
            let original = Data("broken json".utf8)
            defaults.set(original, forKey: "searchHistory.v1")
            let store = UserDefaultsSearchHistoryStore(defaults: defaults)

            XCTAssertThrowsError(try RememberCityUseCase(reader: store, writer: store).execute(city: cities[0])) { error in
                XCTAssertEqual(error as? HistoryFailure, .invalidData)
            }
            XCTAssertEqual(defaults.data(forKey: "searchHistory.v1"), original)
        }
    }

    private func withDefaults(_ test: (UserDefaults) throws -> Void) throws {
        let suite = "EWaeatherTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try test(defaults)
    }
}

@MainActor
final class FailingHistoryStore: SearchHistoryReading, SearchHistoryWriting {
    var failsToRead = false

    func loadHistory() throws -> [City] {
        if failsToRead { throw HistoryFailure.unavailable }
        return []
    }

    func saveHistory(_ cities: [City]) throws { throw HistoryFailure.unavailable }
}
