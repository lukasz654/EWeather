import XCTest
import WeatherDomain
import WeatherData

@MainActor
final class SearchHistoryStoreTests: XCTestCase {
    func testNewHistoryIsEmpty() throws {
        try withDefaults { defaults in
            XCTAssertEqual(try UserDefaultsSearchHistoryStore(defaults: defaults).loadHistory(), [])
        }
    }

    func testOptionalLocationDetailsSurviveStorage() throws {
        try withDefaults { defaults in
            let city = City(id: 500, name: "City", region: nil, country: nil, latitude: 0, longitude: 0, timeZoneIdentifier: "GMT")
            let store = UserDefaultsSearchHistoryStore(defaults: defaults)
            try store.saveHistory([city])
            XCTAssertEqual(try store.loadHistory(), [city])
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

    private func withDefaults(_ test: (UserDefaults) throws -> Void) throws {
        let suite = "EWaeatherTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try test(defaults)
    }
}
