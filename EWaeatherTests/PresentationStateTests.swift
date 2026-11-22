import XCTest
@testable import EWaeather

@MainActor
final class PresentationStateTests: XCTestCase {
    private let city = SampleWeatherRepository.cities[0]

    func testSearchDisplaysEmptyResultsWithoutHidingHistory() async {
        let model = SearchViewModel(searchCities: SearchCitiesUseCase(repository: SampleWeatherRepository()), history: [city])
        model.query = "Nieistniejące miasto"

        await model.search()

        XCTAssertEqual(model.state, .empty)
        XCTAssertEqual(model.history, [city])
    }

    func testClearingQueryRestoresInitialState() async {
        let model = SearchViewModel(searchCities: SearchCitiesUseCase(repository: SampleWeatherRepository()), history: [city])
        model.query = "Bielsko"
        await model.search()
        XCTAssertEqual(model.state, .results([city]))

        model.query = "   "
        await model.search()

        XCTAssertEqual(model.state, .idle)
    }

    func testOldSearchCannotReplaceNewerResults() async {
        let repository = ControlledSearchRepository()
        let model = SearchViewModel(searchCities: SearchCitiesUseCase(repository: repository), history: [])
        model.query = "old"
        let oldRequest = Task { await model.search() }
        await repository.waitUntilStarted("old")
        model.query = "new"
        let newRequest = Task { await model.search() }
        await repository.waitUntilStarted("new")

        await repository.finish("new", cities: [city])
        await newRequest.value
        await repository.finish("old", cities: [])
        await oldRequest.value

        XCTAssertEqual(model.state, .results([city]))
    }

    func testForecastShowsOfflineAndCanRetry() async {
        let forecast = SampleWeatherRepository.forecast()
        let repository = SequenceForecastRepository(responses: [.failure(.offline), .success(forecast)])
        let model = ForecastViewModel(city: city, getForecast: GetForecastUseCase(repository: repository))

        await model.loadIfNeeded()
        XCTAssertEqual(model.state, .failed(.offline))

        await model.reload()
        XCTAssertEqual(model.state, .loaded(forecast))
    }

    func testForecastDistinguishesEmptyDataFromAnError() async {
        let repository = SequenceForecastRepository(responses: [.success(nil)])
        let model = ForecastViewModel(city: city, getForecast: GetForecastUseCase(repository: repository))

        await model.loadIfNeeded()

        XCTAssertEqual(model.state, .empty)
    }

    func testReappearingForecastDoesNotReloadLoadedData() async {
        let repository = SequenceForecastRepository(responses: [.success(SampleWeatherRepository.forecast())])
        let model = ForecastViewModel(city: city, getForecast: GetForecastUseCase(repository: repository))

        await model.loadIfNeeded()
        await model.loadIfNeeded()

        let count = await repository.callCount
        XCTAssertEqual(count, 1)
    }

    func testCancelledForecastDoesNotShowAnError() async {
        let model = ForecastViewModel(city: city, getForecast: GetForecastUseCase(repository: CancelledForecastRepository()))

        await model.loadIfNeeded()

        XCTAssertEqual(model.state, .idle)
    }

    func testMissingWeatherValuesAreNotPresentedAsZero() {
        XCTAssertEqual(WeatherFormatting.temperature(nil), "Brak danych")
        XCTAssertEqual(WeatherFormatting.percent(nil), "Brak danych")
    }

    func testTimeIsFormattedInTheCityTimeZone() {
        let date = Date(timeIntervalSince1970: 0)
        let warsaw = WeatherFormatting.time(date, timeZoneIdentifier: "Europe/Warsaw")
        let utc = WeatherFormatting.time(date, timeZoneIdentifier: "GMT")

        XCTAssertEqual(warsaw, "01:00")
        XCTAssertEqual(utc, "00:00")
    }
}

private actor SequenceForecastRepository: ForecastProviding {
    let responses: [Result<Forecast?, WeatherFailure>]
    private(set) var callCount = 0

    init(responses: [Result<Forecast?, WeatherFailure>]) { self.responses = responses }

    func forecast(for city: City) async throws -> Forecast? {
        let index = callCount
        callCount += 1
        guard responses.indices.contains(index) else { throw WeatherFailure.unavailable }
        return try responses[index].get()
    }
}

private struct CancelledForecastRepository: ForecastProviding {
    func forecast(for city: City) async throws -> Forecast? { throw CancellationError() }
}

private actor ControlledSearchRepository: CitySearching {
    private var pending: [String: CheckedContinuation<[City], Never>] = [:]
    private var startWaiters: [String: CheckedContinuation<Void, Never>] = [:]

    func searchCities(named query: String) async throws -> [City] {
        await withCheckedContinuation { continuation in
            pending[query] = continuation
            startWaiters.removeValue(forKey: query)?.resume()
        }
    }

    func waitUntilStarted(_ query: String) async {
        guard pending[query] == nil else { return }
        await withCheckedContinuation { startWaiters[query] = $0 }
    }

    func finish(_ query: String, cities: [City]) {
        pending.removeValue(forKey: query)?.resume(returning: cities)
    }
}
