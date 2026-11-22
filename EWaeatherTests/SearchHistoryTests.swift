import WeatherDomain
import XCTest
@testable import EWaeather

@MainActor
final class SearchHistoryTests: XCTestCase {
    private let cities = SampleWeatherRepository.cities

    func testNewHistoryIsEmpty() throws {
        try withDefaults { defaults in
            XCTAssertEqual(try UserDefaultsSearchHistoryStore(defaults: defaults).loadHistory(), [])
        }
    }

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

    func testSelectingTheSameIdentifierMovesUpdatedCityToFront() throws {
        let oldCity = cities[0]
        let updatedCity = City(id: oldCity.id, name: "Updated name", region: nil, country: oldCity.country, latitude: 50, longitude: 20, timeZoneIdentifier: "GMT")
        let store = MemorySearchHistoryStore(cities: [cities[1], oldCity, cities[2], oldCity])

        let result = try RememberCityUseCase(reader: store, writer: store).execute(city: updatedCity)

        XCTAssertEqual(result, [updatedCity, cities[1], cities[2]])
        XCTAssertEqual(try store.loadHistory(), result)
    }

    func testCitiesWithTheSameNameAndDifferentIdentifiersAreKept() throws {
        let other = City(id: 500, name: cities[0].name, region: nil, country: nil, latitude: 0, longitude: 0, timeZoneIdentifier: "GMT")
        let store = MemorySearchHistoryStore(cities: [cities[0]])

        let result = try RememberCityUseCase(reader: store, writer: store).execute(city: other)

        XCTAssertEqual(result, [other, cities[0]])
    }

    func testLoadingRemovesDuplicateIdentifiersAndKeepsFirstOccurrence() throws {
        let store = MemorySearchHistoryStore(cities: [cities[1], cities[0], cities[1]])
        XCTAssertEqual(try LoadSearchHistoryUseCase(repository: store).execute(), [cities[1], cities[0]])
    }

    func testOptionalLocationDetailsSurviveStorage() throws {
        try withDefaults { defaults in
            let city = City(id: 500, name: "City", region: nil, country: nil, latitude: 0, longitude: 0, timeZoneIdentifier: "GMT")
            let store = UserDefaultsSearchHistoryStore(defaults: defaults)
            try store.saveHistory([city])
            XCTAssertEqual(try store.loadHistory(), [city])
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

    func testWrongStoredTypeAndInvalidCoordinatesAreReported() throws {
        try withDefaults { defaults in
            let store = UserDefaultsSearchHistoryStore(defaults: defaults)
            defaults.set("wrong type", forKey: "searchHistory.v1")
            XCTAssertThrowsError(try store.loadHistory())
            let body = #"[{"id":1,"name":"City","latitude":200,"longitude":20,"timeZoneIdentifier":"GMT"}]"#
            defaults.set(Data(body.utf8), forKey: "searchHistory.v1")
            XCTAssertThrowsError(try store.loadHistory())
        }
    }

    func testWriteFailureDoesNotReturnASuccessfulHistory() {
        let store = FailingHistoryStore()
        XCTAssertThrowsError(try RememberCityUseCase(reader: store, writer: store).execute(city: cities[0]))
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
