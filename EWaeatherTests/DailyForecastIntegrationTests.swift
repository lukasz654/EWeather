import Foundation
import XCTest
import WeatherDomain
import WeatherData
@testable import EWaeather

@MainActor
final class DailyForecastIntegrationTests: XCTestCase {
    private let city = SampleWeatherRepository.cities[0]

    func testDailyFailureAndRetryKeepTheLoadedCurrentForecast() async throws {
        let body = try dailyBody(minimum: 2, maximum: 8)
        let transport = DailyIntegrationTransport(dailyReplies: [(503, "Unavailable"), (200, body)])
        let composition = composition(transport)
        let current = composition.makeForecastModel(city: city)
        let daily = composition.makeDailyForecastModel(city: city)
        await current.loadIfNeeded()
        let original = current.state
        guard case .loaded(let forecast) = original else { return XCTFail("Expected current weather") }
        XCTAssertEqual(forecast.temperature, 8)

        await daily.loadIfNeeded()
        XCTAssertEqual(daily.state, .failed(.unavailable))
        XCTAssertEqual(current.state, original)
        await daily.loadIfNeeded()
        XCTAssertEqual(try loadedDays(daily).count, 3)
        XCTAssertEqual(current.state, original)
        let currentCalls = await transport.currentCalls
        let dailyPoints = await transport.dailyPoints
        XCTAssertEqual(currentCalls, 1)
        XCTAssertEqual(dailyPoints.count, 2)
    }

    func testCurrentFailureDoesNotPreventDailyForecastLoading() async throws {
        let transport = DailyIntegrationTransport(currentStatus: 503, dailyReplies: [(200, try dailyBody(minimum: 2, maximum: 8))])
        let composition = composition(transport)
        let current = composition.makeForecastModel(city: city)
        let daily = composition.makeDailyForecastModel(city: city)
        await current.loadIfNeeded()
        XCTAssertEqual(current.state, .failed(.unavailable))
        await daily.loadIfNeeded()
        XCTAssertEqual(try loadedDays(daily).count, 3)
        XCTAssertEqual(current.state, .failed(.unavailable))
    }

    func testEachCityUsesItsCoordinatesAndReopeningMakesANewRequest() async throws {
        let otherCity = SampleWeatherRepository.cities[1]
        let transport = DailyIntegrationTransport(dailyBodies: [
            point(city): try dailyBody(minimum: 2, maximum: 8),
            point(otherCity): try dailyBody(minimum: -5, maximum: 1)
        ])
        let composition = composition(transport)
        let first = composition.makeDailyForecastModel(city: city)
        let second = composition.makeDailyForecastModel(city: otherCity)
        await first.loadIfNeeded()
        await first.loadIfNeeded()
        await second.loadIfNeeded()
        XCTAssertEqual(try loadedDays(first).first?.minimumTemperature, 2)
        XCTAssertEqual(try loadedDays(second).first?.minimumTemperature, -5)
        let reopened = composition.makeDailyForecastModel(city: city)
        await reopened.loadIfNeeded()
        XCTAssertEqual(try loadedDays(reopened), try loadedDays(first))
        let points = await transport.dailyPoints
        XCTAssertEqual(points, [point(city), point(otherCity), point(city)])
    }

    func testPartialDailyDataKeepsMissingValuesThroughComposition() async throws {
        let json = try dailyBody(minimum: NSNull(), maximum: 8, probability: NSNull(), condition: 999)
        let model = composition(DailyIntegrationTransport(dailyReplies: [(200, json)])).makeDailyForecastModel(city: city)
        await model.loadIfNeeded()
        let days = try loadedDays(model)
        XCTAssertEqual(days.count, 3)
        XCTAssertNil(days[0].minimumTemperature)
        XCTAssertNil(days[0].maximumPrecipitationProbability)
        XCTAssertEqual(days[0].maximumTemperature, 8)
        XCTAssertEqual(days[0].condition, .unknown)
        XCTAssertEqual(WeatherFormatting.temperature(days[0].minimumTemperature), "Brak danych")
        XCTAssertEqual(WeatherFormatting.percent(days[0].maximumPrecipitationProbability), "Brak danych")
        XCTAssertEqual(DailyWeatherFormatting.description(days[0].condition), "Brak opisu pogody")
    }

    func testHourlyRangeChangesRequestTheSelectedWindowWithoutReloadingDailyWeather() async throws {
        let transport = DailyIntegrationTransport(
            dailyReplies: [(200, try dailyBody(minimum: 2, maximum: 8))],
            currentBody: try hourlyBody()
        )
        let composition = composition(transport)
        let current = composition.makeForecastModel(city: city)
        let daily = composition.makeDailyForecastModel(city: city)
        await daily.loadIfNeeded()
        let dailyState = daily.state
        let ranges: [(HourlyForecastRange, Int)] = [(.three, 3), (.five, 5), (.eight, 8), (.twelve, 12)]
        for (range, expectedCount) in ranges {
            current.selectRange(range)
            await current.loadIfNeeded()
            guard case .loaded(let forecast) = current.state else { return XCTFail("Expected hourly weather") }
            XCTAssertEqual(forecast.hours.count, expectedCount)
            XCTAssertEqual(forecast.temperature, 8)
            XCTAssertEqual(forecast.cloudCover, 65)
            XCTAssertEqual(forecast.precipitationProbability, 30)
            XCTAssertEqual(daily.state, dailyState)
        }
        let requests = await transport.currentHourCounts
        let dailyRequests = await transport.dailyPoints
        XCTAssertEqual(requests, ["4", "6", "9", "13"])
        XCTAssertEqual(dailyRequests.count, 1)
    }

    private func hourlyBody() throws -> String {
        let start = 1_795_352_400
        let json: [String: Any] = [
            "timezone": "Europe/Warsaw",
            "current_units": ["time": "unixtime", "temperature_2m": "°C", "cloud_cover": "%"],
            "current": ["time": start, "temperature_2m": 8, "cloud_cover": 65],
            "hourly_units": ["time": "unixtime", "temperature_2m": "°C", "precipitation_probability": "%"],
            "hourly": [
                "time": (0...12).map { start + $0 * 3600 },
                "temperature_2m": Array(repeating: 8, count: 13),
                "precipitation_probability": Array(repeating: 30, count: 13)
            ]
        ]
        return try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: json), encoding: .utf8))
    }

    private func composition(_ transport: DailyIntegrationTransport) -> AppComposition {
        AppComposition(
            cityRepository: SampleWeatherRepository(),
            forecastRepository: OpenMeteoForecastRepository(transport: transport),
            dailyForecastRepository: OpenMeteoDailyForecastRepository(transport: transport),
            historyStore: MemorySearchHistoryStore()
        )
    }

    private func point(_ city: City) -> String { "\(city.latitude),\(city.longitude)" }

    private func loadedDays(_ model: DailyForecastViewModel, file: StaticString = #filePath, line: UInt = #line) throws -> [DailyForecast] {
        guard case .loaded(let days) = model.state else {
            XCTFail("Expected loaded daily weather, got \(model.state)", file: file, line: line)
            throw WeatherFailure.invalidData
        }
        return days
    }

    /// Created from the documented contract, not recorded from the service.
    private func dailyBody(minimum: Any, maximum: Any, probability: Any = 30, condition: Int = 2) throws -> String {
        let json: [String: Any] = [
            "timezone": "Europe/Warsaw",
            "daily_units": ["time": "iso8601", "weather_code": "wmo code", "temperature_2m_min": "°C", "temperature_2m_max": "°C", "precipitation_probability_max": "%"],
            "daily": [
                "time": ["2026-11-23", "2026-11-24", "2026-11-25"],
                "temperature_2m_min": Array(repeating: minimum, count: 3),
                "temperature_2m_max": Array(repeating: maximum, count: 3),
                "precipitation_probability_max": Array(repeating: probability, count: 3),
                "weather_code": Array(repeating: condition, count: 3)
            ]
        ]
        return try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: json), encoding: .utf8))
    }
}

private actor DailyIntegrationTransport: HTTPTransport {
    private let currentStatus: Int
    private var dailyReplies: [(Int, String)]
    private let dailyBodies: [String: String]
    private let currentBody: String?
    private(set) var currentCalls = 0
    private(set) var currentHourCounts: [String] = []
    private(set) var dailyPoints: [String] = []

    init(currentStatus: Int = 200, dailyReplies: [(Int, String)] = [], dailyBodies: [String: String] = [:], currentBody: String? = nil) {
        self.currentStatus = currentStatus
        self.dailyReplies = dailyReplies
        self.dailyBodies = dailyBodies
        self.currentBody = currentBody
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let latitude = items.first(where: { $0.name == "latitude" })?.value,
              let longitude = items.first(where: { $0.name == "longitude" })?.value else { throw URLError(.badURL) }
        let status: Int
        let body: String
        if items.contains(where: { $0.name == "daily" }) {
            let point = "\(latitude),\(longitude)"
            dailyPoints.append(point)
            if !dailyReplies.isEmpty {
                (status, body) = dailyReplies.removeFirst()
            } else if let dailyBody = dailyBodies[point] {
                (status, body) = (200, dailyBody)
            } else { throw URLError(.badServerResponse) }
        } else {
            currentCalls += 1
            currentHourCounts.append(items.first(where: { $0.name == "forecast_hours" })?.value ?? "missing")
            status = currentStatus
            body = currentBody ?? #"{"timezone":"Europe/Warsaw","current_units":{"time":"unixtime","temperature_2m":"°C","cloud_cover":"%"},"current":{"time":1795352400,"temperature_2m":8,"cloud_cover":65}}"#
        }
        return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}
