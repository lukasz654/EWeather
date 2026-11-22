import XCTest
import WeatherDomain
import WeatherApplication

@MainActor
final class HistoryUseCaseTests: XCTestCase {
    private let cities = [
        City(id: 1, name: "Bielsko-Biała", region: nil, country: "Polska", latitude: 49.82, longitude: 19.04, timeZoneIdentifier: "Europe/Warsaw"),
        City(id: 2, name: "Nowy Sącz", region: nil, country: "Polska", latitude: 49.62, longitude: 20.7, timeZoneIdentifier: "Europe/Warsaw"),
        City(id: 3, name: "Warszawa", region: nil, country: "Polska", latitude: 52.23, longitude: 21.01, timeZoneIdentifier: "Europe/Warsaw")
    ]

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

    func testWriteFailureDoesNotReturnASuccessfulHistory() {
        let store = FailingHistoryStore()
        XCTAssertThrowsError(try RememberCityUseCase(reader: store, writer: store).execute(city: cities[0]))
    }
}

@MainActor
private final class MemorySearchHistoryStore: SearchHistoryReading, SearchHistoryWriting {
    private var cities: [City]
    init(cities: [City]) { self.cities = cities }
    func loadHistory() throws -> [City] { cities }
    func saveHistory(_ cities: [City]) throws { self.cities = cities }
}

@MainActor
private final class FailingHistoryStore: SearchHistoryReading, SearchHistoryWriting {
    func loadHistory() throws -> [City] { [] }
    func saveHistory(_ cities: [City]) throws { throw HistoryFailure.unavailable }
}
