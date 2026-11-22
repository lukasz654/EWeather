import XCTest
@testable import EWaeather

@MainActor
final class ForecastIntegrationTests: XCTestCase {
    private let firstCity = SampleWeatherRepository.cities[0]
    private let secondCity = SampleWeatherRepository.cities[1]

    func testSelectedCitiesLoadTheirOwnWeatherAndReopeningMakesANewRequest() async throws {
        let firstBody = try forecastBody(temperature: 8.5, cloudCover: 65, probability: 30)
        let secondBody = try forecastBody(temperature: 4, cloudCover: 25, probability: 80)
        let transport = RoutingForecastTransport(bodies: [point(firstCity): firstBody, point(secondCity): secondBody])
        let composition = composition(transport: transport)
        let first = composition.makeForecastModel(city: firstCity)
        let second = composition.makeForecastModel(city: secondCity)

        await first.loadIfNeeded()
        await second.loadIfNeeded()
        let firstForecast = try loadedForecast(first)
        let secondForecast = try loadedForecast(second)

        XCTAssertEqual(first.city, firstCity)
        XCTAssertEqual(second.city, secondCity)
        XCTAssertEqual(firstForecast.temperature, 8.5)
        XCTAssertEqual(firstForecast.cloudCover, 65)
        XCTAssertEqual(firstForecast.precipitationProbability, 30)
        XCTAssertEqual(firstForecast.hours.count, 24)
        XCTAssertEqual(firstForecast.precipitationInterval?.duration, 3600)
        XCTAssertEqual(secondForecast.temperature, 4)
        XCTAssertEqual(secondForecast.cloudCover, 25)
        XCTAssertEqual(secondForecast.precipitationProbability, 80)

        await first.loadIfNeeded()
        let requestsBeforeReopening = await transport.points
        XCTAssertEqual(requestsBeforeReopening, [point(firstCity), point(secondCity)])

        let reopened = composition.makeForecastModel(city: firstCity)
        await reopened.loadIfNeeded()
        XCTAssertEqual(try loadedForecast(reopened), firstForecast)
        let requestsAfterReopening = await transport.points
        XCTAssertEqual(requestsAfterReopening, [point(firstCity), point(secondCity), point(firstCity)])
    }

    func testAPIAndNetworkFailuresReachTheScreenAndRetryCanLoadWeather() async throws {
        let success = try forecastBody(temperature: 8, cloudCover: 65, probability: 30)
        let cases: [(ForecastHTTPReply, ForecastState)] = [
            (.failure(.notConnectedToInternet), .failed(.offline)),
            (.response(503, "Unavailable"), .failed(.unavailable)),
            (.response(200, "bad JSON"), .failed(.invalidData)),
            (.response(200, #"{"timezone":"Europe/Warsaw"}"#), .empty)
        ]
        for (reply, expected) in cases {
            let transport = SequenceForecastTransport(replies: [reply, .response(200, success)])
            let model = composition(transport: transport).makeForecastModel(city: firstCity)
            await model.loadIfNeeded()
            XCTAssertEqual(model.state, expected)

            await model.loadIfNeeded()
            XCTAssertEqual(try loadedForecast(model).temperature, 8)
        }
    }

    func testPartialResponsesShowMissingValuesInsteadOfInventedWeather() async throws {
        let body = try forecastBody(temperature: NSNull(), cloudCover: 65, probability: NSNull())
        let model = composition(transport: StubHTTPTransport(body: body)).makeForecastModel(city: firstCity)
        await model.loadIfNeeded()
        let forecast = try loadedForecast(model)

        XCTAssertNil(forecast.temperature)
        XCTAssertNil(forecast.precipitationProbability)
        XCTAssertEqual(forecast.cloudCover, 65)
        XCTAssertEqual(WeatherFormatting.temperature(forecast.temperature), "Brak danych")
        XCTAssertEqual(WeatherFormatting.percent(forecast.precipitationProbability), "Brak danych")
        XCTAssertEqual(forecast.hours.count, 24)
        XCTAssertEqual(forecast.timeZoneIdentifier, "Europe/Warsaw")
    }

    private func composition(transport: any HTTPTransport) -> AppComposition {
        let api = OpenMeteoAPI(client: HTTPClient(transport: transport))
        return AppComposition(
            cityRepository: OpenMeteoCityRepository(api: api),
            forecastRepository: OpenMeteoForecastRepository(api: api), historyStore: MemorySearchHistoryStore()
        )
    }

    private func loadedForecast(_ model: ForecastViewModel, file: StaticString = #filePath, line: UInt = #line) throws -> Forecast {
        guard case .loaded(let forecast) = model.state else {
            XCTFail("Expected loaded forecast, got \(model.state)", file: file, line: line)
            throw WeatherFailure.invalidData
        }
        return forecast
    }

    private func point(_ city: City) -> String { "\(city.latitude),\(city.longitude)" }

    /// Synthetic contract response with a current step and 24 future hourly steps.
    private func forecastBody(temperature: Any, cloudCover: Int, probability: Any) throws -> String {
        let start = 1_795_352_400
        let json: [String: Any] = [
            "timezone": "Europe/Warsaw",
            "current_units": ["time": "unixtime", "temperature_2m": "°C", "cloud_cover": "%"],
            "current": ["time": start, "temperature_2m": temperature, "cloud_cover": cloudCover],
            "hourly_units": ["time": "unixtime", "temperature_2m": "°C", "precipitation_probability": "%"],
            "hourly": [
                "time": (0..<25).map { start + $0 * 3600 },
                "temperature_2m": Array(repeating: 7, count: 25),
                "precipitation_probability": Array(repeating: probability, count: 25)
            ]
        ]
        return try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: json), encoding: .utf8))
    }
}

private actor RoutingForecastTransport: HTTPTransport {
    let bodies: [String: String]
    private(set) var points: [String] = []

    init(bodies: [String: String]) { self.bodies = bodies }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let latitude = items.first(where: { $0.name == "latitude" })?.value,
              let longitude = items.first(where: { $0.name == "longitude" })?.value,
              let body = bodies["\(latitude),\(longitude)"] else { throw URLError(.badURL) }
        points.append("\(latitude),\(longitude)")
        return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

private enum ForecastHTTPReply: Sendable {
    case failure(URLError.Code)
    case response(Int, String)
}

private actor SequenceForecastTransport: HTTPTransport {
    private var replies: [ForecastHTTPReply]

    init(replies: [ForecastHTTPReply]) { self.replies = replies }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard !replies.isEmpty, let url = request.url else { throw URLError(.badURL) }
        switch replies.removeFirst() {
        case .failure(let code): throw URLError(code)
        case .response(let status, let body):
            return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }
}
