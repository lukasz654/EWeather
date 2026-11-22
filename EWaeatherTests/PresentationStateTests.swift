import WeatherApplication
import WeatherDomain
import XCTest
@testable import EWaeather

@MainActor
final class PresentationStateTests: XCTestCase {
    private let city = SampleWeatherRepository.cities[0]

    func testSearchDisplaysEmptyResultsWithoutHidingHistory() async {
        let model = makeSearchModel(repository: SampleWeatherRepository(), history: [city])
        model.updateQuery("Nieistniejące miasto")

        await model.search()

        XCTAssertEqual(model.state, .empty)
        XCTAssertEqual(model.history, [city])
    }

    func testClearingQueryRestoresInitialState() async {
        let model = makeSearchModel(repository: SampleWeatherRepository(), history: [city])
        model.updateQuery("Bielsko")
        await model.search()
        XCTAssertEqual(model.state, .results([city]))

        model.updateQuery("   ")
        await model.search()

        XCTAssertEqual(model.state, .idle)
    }

    func testOldSearchCannotReplaceNewerResults() async {
        let repository = ControlledSearchRepository()
        let model = makeSearchModel(repository: repository)
        model.updateQuery("old")
        let oldRequest = Task { await model.search() }
        await repository.waitUntilStarted("old")
        model.updateQuery("new")
        let newRequest = Task { await model.search() }
        await repository.waitUntilStarted("new")

        await repository.finish("new", cities: [city])
        await newRequest.value
        await repository.finish("old", cities: [])
        await oldRequest.value

        XCTAssertEqual(model.state, .results([city]))
    }

    private func makeSearchModel(repository: any CitySearching, history: [City] = []) -> SearchViewModel {
        let store = MemorySearchHistoryStore(cities: history)
        return SearchViewModel(
            searchCities: SearchCitiesUseCase(repository: repository),
            loadHistory: LoadSearchHistoryUseCase(repository: store),
            rememberCity: RememberCityUseCase(reader: store, writer: store), searchDelay: {}
        )
    }

    func testForecastShowsOfflineAndCanRetry() async {
        let forecast = SampleWeatherRepository.forecast()
        let repository = SequenceForecastRepository(responses: [.failure(.offline), .success(SampleWeatherRepository.snapshot())])
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
        let repository = SequenceForecastRepository(responses: [.success(SampleWeatherRepository.snapshot())])
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

    func testRainIntervalKeepsBothDatesWhenItCrossesLocalMidnight() {
        let interval = DateInterval(start: Date(timeIntervalSince1970: 22 * 3600), duration: 3600)

        let text = WeatherFormatting.interval(interval, timeZoneIdentifier: "Europe/Warsaw")

        XCTAssertTrue(text.contains("1 sty"))
        XCTAssertTrue(text.contains("2 sty"))
        XCTAssertTrue(text.contains("23:00"))
        XCTAssertTrue(text.contains("00:00"))
        XCTAssertFalse(text.contains("1970"))
    }

    func testRainIntervalDoesNotRepeatTheDateWithinOneLocalDay() {
        let interval = DateInterval(start: Date(timeIntervalSince1970: 12 * 3600), duration: 3600)

        let text = WeatherFormatting.interval(interval, timeZoneIdentifier: "Europe/Warsaw")

        XCTAssertTrue(text.contains("13:00"))
        XCTAssertTrue(text.hasSuffix(" – 14:00"))
        XCTAssertFalse(text.contains("1970"))
    }
}

private actor SequenceForecastRepository: ForecastProviding {
    let responses: [Result<WeatherSnapshot?, WeatherFailure>]
    private(set) var callCount = 0

    init(responses: [Result<WeatherSnapshot?, WeatherFailure>]) { self.responses = responses }

    func forecast(for city: City) async throws -> WeatherSnapshot? {
        let index = callCount
        callCount += 1
        guard responses.indices.contains(index) else { throw WeatherFailure.unavailable }
        return try responses[index].get()
    }
}

private struct CancelledForecastRepository: ForecastProviding {
    func forecast(for city: City) async throws -> WeatherSnapshot? { throw CancellationError() }
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
