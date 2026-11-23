import WeatherData
import WeatherDomain
import XCTest
@testable import WeatherData

@MainActor
final class OpenMeteoRepositoryTests: XCTestCase {
    private let city = City(id: 1, name: "Bielsko-Biała", region: nil, country: "Polska", latitude: 49.82, longitude: 19.04, timeZoneIdentifier: "Europe/Warsaw")

    func testSearchEncodesPolishNamesSpacesAndHyphens() async throws {
        for name in ["Bielsko-Biała", "Nowy Sącz"] {
            let transport = StubHTTPTransport(body: #"{"results":[]}"#)
            _ = try await cityRepository(transport).searchCities(named: name)

            let request = await transport.lastRequest
            let url = try XCTUnwrap(request?.url)
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            let query = queryValues(components)
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "geocoding-api.open-meteo.com")
            XCTAssertEqual(url.path, "/v1/search")
            XCTAssertEqual(query["name"], name)
            XCTAssertEqual(query["language"], "pl")
            XCTAssertEqual(query["count"], "10")
            XCTAssertNil(query["countryCode"])
        }
    }

    func testCitiesKeepIdentityCoordinatesAndOptionalLocationDetails() async throws {
        let body = #"{"results":[{"id":123,"name":"Nowy Sącz","latitude":49.62,"longitude":20.7,"admin1":"Małopolskie","country":"Polska","timezone":"Europe/Warsaw"},{"id":456,"name":"Other","latitude":0,"longitude":0}]}"#
        let cities = try await cityRepository(StubHTTPTransport(body: body)).searchCities(named: "Nowy Sącz")

        XCTAssertEqual(cities.count, 2)
        XCTAssertEqual(cities[0], City(id: 123, name: "Nowy Sącz", region: "Małopolskie", country: "Polska", latitude: 49.62, longitude: 20.7, timeZoneIdentifier: "Europe/Warsaw"))
        XCTAssertNil(cities[1].region)
        XCTAssertNil(cities[1].country)
        XCTAssertEqual(cities[1].timeZoneIdentifier, "GMT")
    }

    func testOmittedOrEmptyResultsAreEmptySearches() async throws {
        for body in [#"{"generationtime_ms":0.1}"#, #"{"results":[]}"#] {
            let cities = try await cityRepository(StubHTTPTransport(body: body)).searchCities(named: "Missing")
            XCTAssertEqual(cities, [])
        }
    }

    func testBrokenCityRecordsAreDataErrors() async {
        for body in [
            #"{"results":[{"id":1,"name":"City","longitude":20}]}"#,
            #"{"results":[{"id":1,"name":"City","latitude":91,"longitude":20}]}"#,
            #"{"results":[{"id":1,"name":" ","latitude":50,"longitude":20}]}"#
        ] {
            await assertWeatherFailure(.invalidData) {
                _ = try await self.cityRepository(StubHTTPTransport(body: body)).searchCities(named: "City")
            }
        }
    }

    func testForecastRequestUsesRequiredFieldsUnitsAndAbsoluteTime() async throws {
        let transport = StubHTTPTransport(body: try forecastBody())
        let repository = forecastRepository(transport)
        let snapshot = try await repository.forecast(for: city, range: .three)

        let request = await transport.lastRequest
        let url = try XCTUnwrap(request?.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = queryValues(components)
        XCTAssertEqual(url.host, "api.open-meteo.com")
        XCTAssertEqual(url.path, "/v1/forecast")
        XCTAssertEqual(query["latitude"], String(city.latitude))
        XCTAssertEqual(query["longitude"], String(city.longitude))
        XCTAssertEqual(query["current"], "temperature_2m,cloud_cover")
        XCTAssertEqual(query["hourly"], "temperature_2m,precipitation_probability")
        XCTAssertEqual(query["forecast_hours"], "4")
        XCTAssertEqual(query["temperature_unit"], "celsius")
        XCTAssertEqual(query["timezone"], "auto")
        XCTAssertEqual(query["timeformat"], "unixtime")
        XCTAssertEqual(snapshot?.updatedAt, Date(timeIntervalSince1970: 1_795_352_400))
        XCTAssertEqual(snapshot?.temperature, 8.5)
        XCTAssertEqual(snapshot?.cloudCover, 65)
        XCTAssertEqual(snapshot?.hours.map(\.precipitationProbability), [20, 30, 40])
        XCTAssertEqual(snapshot?.hours[1].time, Date(timeIntervalSince1970: 1_795_356_000))
    }

    func testEveryHourlyRangeControlsTheNumberOfRequestedSteps() async throws {
        for range in HourlyForecastRange.allCases {
            let transport = StubHTTPTransport(body: try forecastBody())
            _ = try await forecastRepository(transport).forecast(for: city, range: range)
            let request = await transport.lastRequest
            let url = try XCTUnwrap(request?.url)
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            let query = queryValues(components)
            XCTAssertEqual(query["forecast_hours"], String(range.rawValue + 1))
            XCTAssertNil(query["daily"])
        }
    }

    func testNullAndOmittedWeatherValuesRemainMissing() async throws {
        let body = try forecastBody { json in
            json["current"] = ["time": 1_795_352_400, "temperature_2m": NSNull()]
            json["hourly"] = ["time": [1_795_352_400, 1_795_356_000], "temperature_2m": [NSNull(), 0]]
        }
        let snapshot = try await forecastRepository(StubHTTPTransport(body: body)).forecast(for: city, range: .three)

        XCTAssertNil(snapshot?.temperature)
        XCTAssertNil(snapshot?.cloudCover)
        XCTAssertNil(snapshot?.hours.first?.temperature)
        XCTAssertNil(snapshot?.hours.first?.precipitationProbability)
        XCTAssertEqual(snapshot?.hours.last?.temperature, 0)
    }

    func testCompletelyMissingWeatherProducesAnEmptyResult() async throws {
        for body in [
            #"{"timezone":"Europe/Warsaw"}"#,
            try forecastBody { json in
                json["current"] = ["time": 1_795_352_400]
                json["hourly"] = ["time": []]
            }
        ] {
            let snapshot = try await forecastRepository(StubHTTPTransport(body: body)).forecast(for: city, range: .three)
            XCTAssertNil(snapshot)
        }
    }

    func testForecastRejectsWrongUnitsUnknownZoneAndMismatchedArrays() async throws {
        let changes: [(inout [String: Any]) -> Void] = [
            { $0["current_units"] = ["time": "unixtime", "temperature_2m": "°F", "cloud_cover": "%"] },
            { $0["hourly_units"] = ["time": "iso8601", "temperature_2m": "°C", "precipitation_probability": "%"] },
            { $0["timezone"] = "Unknown/Zone" },
            { $0["hourly"] = ["time": [1, 2], "temperature_2m": [8]] },
            { $0["hourly"] = ["time": [1, 2], "precipitation_probability": [30]] },
            { $0["hourly"] = ["time": [2, 2]] },
            { $0["hourly"] = ["time": [2, 1]] },
            { $0["current"] = ["time": 1, "cloud_cover": 101] },
            { $0["hourly"] = ["time": [1], "precipitation_probability": [-1]] },
            { $0["current"] = NSNull() }
        ]
        for change in changes {
            let body = try forecastBody(change)
            await assertWeatherFailure(.invalidData) {
                _ = try await self.forecastRepository(StubHTTPTransport(body: body)).forecast(for: self.city, range: .three)
            }
        }
    }

    func testBothRepositoriesTranslateInfrastructureErrors() async {
        let cases: [(StubHTTPTransport, WeatherFailure)] = [
            (StubHTTPTransport(status: 400, body: #"{"error":true,"reason":"Invalid parameter"}"#), .unavailable),
            (StubHTTPTransport(status: 429), .unavailable),
            (StubHTTPTransport(status: 503), .unavailable),
            (StubHTTPTransport(body: "bad JSON"), .invalidData),
            (StubHTTPTransport(error: URLError(.notConnectedToInternet)), .offline),
            (StubHTTPTransport(error: URLError(.timedOut)), .unavailable)
        ]
        for (transport, failure) in cases {
            await assertWeatherFailure(failure) {
                _ = try await self.cityRepository(transport).searchCities(named: "City")
            }
            await assertWeatherFailure(failure) {
                _ = try await self.forecastRepository(transport).forecast(for: self.city, range: .three)
            }
        }
    }

    func testBothRepositoriesPreserveCancellation() async {
        let transport = StubHTTPTransport(error: URLError(.cancelled))
        do {
            _ = try await cityRepository(transport).searchCities(named: "City")
            XCTFail("Expected cancellation")
        } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        do {
            _ = try await forecastRepository(transport).forecast(for: city, range: .three)
            XCTFail("Expected cancellation")
        } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
    }

    func testInvalidCoordinatesAreRejectedBeforeSending() async {
        let transport = StubHTTPTransport()
        let invalidCity = City(id: 1, name: "Invalid", region: nil, country: nil, latitude: .nan, longitude: 20, timeZoneIdentifier: "GMT")
        await assertWeatherFailure(.invalidData) {
            _ = try await self.forecastRepository(transport).forecast(for: invalidCity, range: .three)
        }
        let request = await transport.lastRequest
        XCTAssertNil(request)
    }

    private func cityRepository(_ transport: StubHTTPTransport) -> OpenMeteoCityRepository {
        OpenMeteoCityRepository(api: OpenMeteoAPI(client: HTTPClient(transport: transport)))
    }

    private func forecastRepository(_ transport: StubHTTPTransport) -> OpenMeteoForecastRepository {
        OpenMeteoForecastRepository(api: OpenMeteoAPI(client: HTTPClient(transport: transport)))
    }

    private func queryValues(_ components: URLComponents) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }

    /// Hand-written contract fixture based on the documentation; not a live API recording.
    private func forecastBody(_ change: (inout [String: Any]) -> Void = { _ in }) throws -> String {
        var json: [String: Any] = [
            "timezone": "Europe/Warsaw",
            "current_units": ["time": "unixtime", "temperature_2m": "°C", "cloud_cover": "%"],
            "current": ["time": 1_795_352_400, "temperature_2m": 8.5, "cloud_cover": 65],
            "hourly_units": ["time": "unixtime", "temperature_2m": "°C", "precipitation_probability": "%"],
            "hourly": ["time": [1_795_352_400, 1_795_356_000, 1_795_359_600], "temperature_2m": [8.5, 8, 7], "precipitation_probability": [20, 30, 40]]
        ]
        change(&json)
        let data = try JSONSerialization.data(withJSONObject: json)
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    private func assertWeatherFailure(_ expected: WeatherFailure, operation: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? WeatherFailure, expected, file: file, line: line)
        }
    }
}
