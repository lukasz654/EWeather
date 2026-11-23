import XCTest
import WeatherDomain
@testable import WeatherData

@MainActor
final class OpenMeteoDailyForecastRepositoryTests: XCTestCase {
    private let city = City(id: 1, name: "Nowy Sącz", region: nil, country: "Polska", latitude: 49.62, longitude: 20.7, timeZoneIdentifier: "Europe/Warsaw")

    func testRequestAsksOnlyForThreeLocalCalendarDays() async throws {
        let transport = StubHTTPTransport(body: try body())
        _ = try await OpenMeteoDailyForecastRepository(transport: transport).dailyForecast(for: city)
        let request = await transport.lastRequest
        let url = try XCTUnwrap(request?.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "api.open-meteo.com")
        XCTAssertEqual(url.path, "/v1/forecast")
        XCTAssertEqual(query["latitude"], String(city.latitude))
        XCTAssertEqual(query["longitude"], String(city.longitude))
        XCTAssertEqual(query["forecast_days"], "3")
        XCTAssertEqual(query["daily"], "weather_code,temperature_2m_min,temperature_2m_max,precipitation_probability_max")
        XCTAssertEqual(query["timeformat"], "iso8601")
        XCTAssertEqual(query["temperature_unit"], "celsius")
        XCTAssertEqual(query["timezone"], "auto")
        XCTAssertNil(query["current"])
        XCTAssertNil(query["hourly"])
        XCTAssertNil(query["forecast_hours"])
    }

    func testMapsTemperaturesMaximumProbabilityAndLocalDates() async throws {
        let days = try await repository(try body()).dailyForecast(for: city)
        XCTAssertEqual(days.count, 3)
        XCTAssertEqual(days[0].day, ForecastDay(year: 2026, month: 11, day: 23))
        XCTAssertEqual(days[0].minimumTemperature, 2)
        XCTAssertEqual(days[0].maximumTemperature, 8)
        XCTAssertEqual(days[0].maximumPrecipitationProbability, 30)
        XCTAssertEqual(days[0].condition, .partlyCloudy)
    }

    func testDateOnlyValuesKeepTheCalendarDayAcrossClockChanges() async throws {
        for dates in [["2026-03-28", "2026-03-29", "2026-03-30"], ["2026-10-24", "2026-10-25", "2026-10-26"], ["2026-12-31", "2027-01-01", "2027-01-02"]] {
            let days = try await repository(try body(dates: dates)).dailyForecast(for: city)
            XCTAssertEqual(days.map { String(format: "%04d-%02d-%02d", $0.day.year, $0.day.month, $0.day.day) }, dates)
        }
    }

    func testNullAndOmittedFieldsStayMissingAndUnknownCodesHaveAFallback() async throws {
        let json = try body { daily in
            daily["temperature_2m_min"] = [NSNull(), 0, 2]
            daily.removeValue(forKey: "temperature_2m_max")
            daily["precipitation_probability_max"] = [NSNull(), 0, 30]
            daily["weather_code"] = [NSNull(), 999, 0]
        }
        let days = try await repository(json).dailyForecast(for: city)
        XCTAssertNil(days[0].minimumTemperature)
        XCTAssertNil(days[0].maximumTemperature)
        XCTAssertNil(days[0].maximumPrecipitationProbability)
        XCTAssertEqual(days[0].condition, .unknown)
        XCTAssertEqual(days[1].minimumTemperature, 0)
        XCTAssertEqual(days[1].maximumPrecipitationProbability, 0)
        XCTAssertEqual(days[1].condition, .unknown)
        XCTAssertEqual(days[2].condition, .clearSky)
    }

    func testMissingDailyObjectAndEmptyDatesProduceNoDays() async throws {
        for json in [#"{"timezone":"Europe/Warsaw"}"#, #"{"timezone":"Europe/Warsaw","daily":{"time":[]}}"#] {
            let days = try await repository(json).dailyForecast(for: city)
            XCTAssertEqual(days, [])
        }
    }

    func testRejectsInvalidUnitsUnknownZoneAndMissingDates() async throws {
        for (field, value) in [
            ("temperature_2m_min", "°F"), ("time", "unixtime"),
            ("precipitation_probability_max", "mm"), ("weather_code", "unknown")
        ] {
            let json = try changingRoot { root in
                var units = root["daily_units"] as! [String: String]
                units[field] = value
                root["daily_units"] = units
            }
            await assertFailure(.invalidData, transport: StubHTTPTransport(body: json))
        }
        let unknownZone = try changingRoot { $0["timezone"] = "Unknown/Zone" }
        await assertFailure(.invalidData, transport: StubHTTPTransport(body: unknownZone))
        await assertFailure(.invalidData, transport: StubHTTPTransport(body: #"{"timezone":"Europe/Warsaw","daily":{}}"#))
    }

    func testRejectsMalformedCalendarDatesDuplicatesAndWrongOrder() async throws {
        for dates in [["2026-02-29"], ["2026-1-01"], ["2026-01-01T00:00"], ["2026-13-01"], ["0000-01-01"], ["2026-11-23", "2026-11-23"], ["2026-11-24", "2026-11-23"]] {
            await assertFailure(.invalidData, transport: StubHTTPTransport(body: try body(dates: dates)))
        }
    }

    func testRejectsMismatchedArraysInvalidPercentagesAndReversedTemperatures() async throws {
        let changes: [(inout [String: Any]) -> Void] = [
            { $0["temperature_2m_min"] = [1] },
            { $0["temperature_2m_max"] = [8] },
            { $0["precipitation_probability_max"] = [20] },
            { $0["weather_code"] = [0] },
            { $0["precipitation_probability_max"] = [-1, 30, 40] },
            { $0["precipitation_probability_max"] = [101, 30, 40] },
            { $0["temperature_2m_min"] = [9, 2, 2] }
        ]
        for change in changes {
            await assertFailure(.invalidData, transport: StubHTTPTransport(body: try body(change: change)))
        }
    }

    func testMapsTheDocumentedWeatherCodeMeanings() async throws {
        let cases: [(Int, DailyWeatherCondition)] = [
            (0, .clearSky), (1, .mainlyClear), (2, .partlyCloudy), (3, .overcast), (45, .fog), (48, .rimeFog),
            (51, .lightDrizzle), (53, .moderateDrizzle), (55, .denseDrizzle), (56, .lightFreezingDrizzle), (57, .denseFreezingDrizzle),
            (61, .lightRain), (63, .moderateRain), (65, .heavyRain), (66, .lightFreezingRain), (67, .heavyFreezingRain),
            (71, .lightSnow), (73, .moderateSnow), (75, .heavySnow), (77, .snowGrains),
            (80, .lightRainShowers), (81, .moderateRainShowers), (82, .violentRainShowers),
            (85, .lightSnowShowers), (86, .heavySnowShowers), (95, .thunderstorm),
            (96, .thunderstormWithLightHail), (97, .heavyThunderstorm), (99, .thunderstormWithHeavyHail)
        ]
        for (code, condition) in cases {
            let json = try body(dates: ["2026-11-23"]) { $0["weather_code"] = [code] }
            let days = try await repository(json).dailyForecast(for: city)
            XCTAssertEqual(days.first?.condition, condition, "WMO code \(code)")
        }
    }

    func testInfrastructureFailuresAndCancellationKeepTheirMeaning() async {
        for (transport, expected) in [
            (StubHTTPTransport(error: URLError(.notConnectedToInternet)), WeatherFailure.offline),
            (StubHTTPTransport(status: 429), .unavailable), (StubHTTPTransport(status: 503), .unavailable),
            (StubHTTPTransport(body: "bad JSON"), .invalidData)
        ] {
            await assertFailure(expected, transport: transport)
        }
        do {
            _ = try await OpenMeteoDailyForecastRepository(transport: StubHTTPTransport(error: URLError(.cancelled))).dailyForecast(for: city)
            XCTFail("Expected cancellation")
        } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
    }

    func testInvalidCoordinatesDoNotSendARequest() async {
        let transport = StubHTTPTransport()
        let city = City(id: 1, name: "City", region: nil, country: nil, latitude: .infinity, longitude: 20, timeZoneIdentifier: "GMT")
        do {
            _ = try await OpenMeteoDailyForecastRepository(transport: transport).dailyForecast(for: city)
            XCTFail("Expected invalid data")
        } catch { XCTAssertEqual(error as? WeatherFailure, .invalidData) }
        let request = await transport.lastRequest
        XCTAssertNil(request)
    }

    private func repository(_ body: String) -> OpenMeteoDailyForecastRepository {
        OpenMeteoDailyForecastRepository(transport: StubHTTPTransport(body: body))
    }

    /// Hand-written contract data, not a recording from the service.
    private func body(dates: [String] = ["2026-11-23", "2026-11-24", "2026-11-25"], change: (inout [String: Any]) -> Void = { _ in }) throws -> String {
        var daily: [String: Any] = [
            "time": dates, "weather_code": Array(repeating: 2, count: dates.count),
            "temperature_2m_min": Array(repeating: 2, count: dates.count),
            "temperature_2m_max": Array(repeating: 8, count: dates.count),
            "precipitation_probability_max": Array(repeating: 30, count: dates.count)
        ]
        change(&daily)
        let json: [String: Any] = [
            "timezone": "Europe/Warsaw",
            "daily_units": ["time": "iso8601", "weather_code": "wmo code", "temperature_2m_min": "°C", "temperature_2m_max": "°C", "precipitation_probability_max": "%"],
            "daily": daily
        ]
        return try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: json), encoding: .utf8))
    }

    private func changingRoot(_ change: (inout [String: Any]) -> Void) throws -> String {
        let original = Data(try body().utf8)
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        change(&root)
        return try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: root), encoding: .utf8))
    }

    private func assertFailure(_ expected: WeatherFailure, transport: StubHTTPTransport, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await OpenMeteoDailyForecastRepository(transport: transport).dailyForecast(for: city)
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch { XCTAssertEqual(error as? WeatherFailure, expected, file: file, line: line) }
    }
}
