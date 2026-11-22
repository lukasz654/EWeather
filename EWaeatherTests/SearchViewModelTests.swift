import WeatherDomain
import XCTest
@testable import EWaeather

@MainActor
final class SearchViewModelTests: XCTestCase {
    private let city = SampleWeatherRepository.cities[0]

    func testInvalidTypingAndPastingKeepTheLastValidQuery() {
        let model = makeModel()
        model.updateQuery("Nowy Sącz")
        for input in ["Nowy Sącz2", "Warszawa!", "Łódź\n", "😎"] {
            model.updateQuery(input)
            XCTAssertEqual(model.query, "Nowy Sącz")
            XCTAssertNotNil(model.validationMessage)
        }
        model.updateQuery("Bielsko-Biała")
        XCTAssertEqual(model.query, "Bielsko-Biała")
        XCTAssertNil(model.validationMessage)
    }

    func testPastedDecomposedLettersBecomeCanonicalText() {
        let model = makeModel()
        model.updateQuery("  Nowy Sa\u{0328}cz  ")
        XCTAssertEqual(model.query, "  Nowy Sącz  ")
    }

    func testShortInputStaysIdleAndKeepsHistoryWithoutSearching() async {
        let repository = SearchStub()
        let model = makeModel(repository: repository, store: MemorySearchHistoryStore(cities: [city]))
        model.updateQuery(" A-")

        await model.search()

        XCTAssertEqual(model.state, .idle)
        XCTAssertEqual(model.history, [city])
        let queries = await repository.queries
        XCTAssertEqual(queries, [])
    }

    func testEditingInvalidatesResultsBeforeTheNextTaskStarts() async {
        let repository = GatedCitySearch()
        let model = makeModel(repository: repository)
        model.updateQuery("Old")
        let request = Task { await model.search() }
        await repository.waitUntilStarted()

        model.updateQuery("New")
        await repository.finish(cities: [city])
        await request.value

        XCTAssertEqual(model.query, "New")
        XCTAssertEqual(model.state, .idle)
    }

    func testDebounceDoesNotRequestAnObsoleteQuery() async {
        let repository = SearchStub()
        let gate = SearchDelayGate()
        let model = makeModel(repository: repository, delay: { await gate.pause() })
        model.updateQuery("Old")
        let request = Task { await model.search() }
        await gate.waitUntilStarted()
        let queriesBeforeDelay = await repository.queries
        XCTAssertEqual(queriesBeforeDelay, [])

        model.updateQuery("New")
        await gate.finish()
        await request.value

        let queriesAfterDelay = await repository.queries
        XCTAssertEqual(queriesAfterDelay, [])
        XCTAssertEqual(model.state, .idle)
    }

    func testCancellationDuringDebounceDoesNotShowAnErrorOrSendARequest() async {
        let repository = SearchStub()
        let gate = SearchDelayGate()
        let model = makeModel(repository: repository, delay: { await gate.pause() })
        model.updateQuery("City")
        let request = Task { await model.search() }
        await gate.waitUntilStarted()
        request.cancel()
        await gate.finish()
        await request.value

        XCTAssertEqual(model.state, .idle)
        let queries = await repository.queries
        XCTAssertEqual(queries, [])
    }

    func testSearchShowsLoadingWhileWaitingForTheResponse() async {
        let repository = GatedCitySearch()
        let model = makeModel(repository: repository)
        model.updateQuery("City")
        let request = Task { await model.search() }
        await repository.waitUntilStarted()
        XCTAssertEqual(model.state, .loading)

        await repository.finish(cities: [city])
        await request.value
        XCTAssertEqual(model.state, .results([city]))
    }

    func testAlreadyCancelledTaskCannotInvalidateAnActiveSearch() async {
        let repository = GatedCitySearch()
        let model = makeModel(repository: repository)
        model.updateQuery("City")
        let active = Task { await model.search() }
        await repository.waitUntilStarted()

        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await model.search()
        }
        await cancelled.value
        XCTAssertEqual(model.state, .loading)
        await repository.finish(cities: [city])
        await active.value
        XCTAssertEqual(model.state, .results([city]))
    }

    func testCancelledInFlightSearchDoesNotDisplayItsResults() async {
        let repository = GatedCitySearch()
        let model = makeModel(repository: repository)
        model.updateQuery("City")
        let request = Task { await model.search() }
        await repository.waitUntilStarted()
        request.cancel()
        await repository.finish(cities: [city])
        await request.value
        XCTAssertEqual(model.state, .idle)
    }

    func testSearchFailuresKeepHistoryAndCanBeRetried() async {
        for failure: WeatherFailure in [.offline, .unavailable, .invalidData] {
            let repository = SearchStub(failure: failure)
            let model = makeModel(repository: repository, store: MemorySearchHistoryStore(cities: [city]))
            model.updateQuery("City")
            await model.search()
            XCTAssertEqual(model.state, .failed(failure))
            XCTAssertEqual(model.history, [city])

            await repository.setResult([city])
            await model.search()
            XCTAssertEqual(model.state, .results([city]))
        }
    }

    func testSearchResultsAreNotSavedUntilACityIsSelected() async {
        let store = MemorySearchHistoryStore()
        let model = makeModel(repository: SearchStub(cities: [city]), store: store)
        model.updateQuery("City")
        await model.search()
        XCTAssertEqual(model.history, [])
        XCTAssertEqual(try store.loadHistory(), [])

        model.remember(city)
        XCTAssertEqual(model.history, [city])
        XCTAssertEqual(try store.loadHistory(), [city])
        XCTAssertEqual(makeModel(store: store).history, [city])
    }

    func testSelectingAHistoryCityMovesItToTheFront() {
        let other = SampleWeatherRepository.cities[1]
        let store = MemorySearchHistoryStore(cities: [other, city])
        let model = makeModel(store: store)
        model.remember(city)
        XCTAssertEqual(model.history, [city, other])
    }

    func testRemoteSearchSelectionSurvivesModelAndStoreRecreation() async throws {
        let suite = "EWaeatherSearchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        // Synthetic location data, not a recording from the live service.
        let body = #"{"results":[{"id":987,"name":"Łódź","latitude":51.7,"longitude":19.4,"country":"Polska","timezone":"Europe/Warsaw"}]}"#
        let repository = OpenMeteoCityRepository(api: OpenMeteoAPI(client: HTTPClient(transport: StubHTTPTransport(body: body))))
        let model = makeModel(repository: repository, store: UserDefaultsSearchHistoryStore(defaults: defaults))
        model.updateQuery("Łódź")
        await model.search()
        guard case .results(let cities) = model.state else { return XCTFail("Expected city results") }
        let selected = try XCTUnwrap(cities.first)
        model.remember(selected)

        let recreatedDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let restoredModel = makeModel(store: UserDefaultsSearchHistoryStore(defaults: recreatedDefaults))
        XCTAssertEqual(restoredModel.history, [selected])
        XCTAssertEqual(restoredModel.history.first?.id, 987)
        XCTAssertEqual(restoredModel.history.first?.latitude, 51.7)
        XCTAssertEqual(restoredModel.history.first?.longitude, 19.4)
    }

    func testHistoryReadFailureIsVisibleAndCanBeRetried() {
        let store = FailingHistoryStore()
        store.failsToRead = true
        let model = makeModel(store: store)
        XCTAssertNotNil(model.historyMessage)

        store.failsToRead = false
        model.retryHistory()
        XCTAssertNil(model.historyMessage)
    }

    func testFailedSaveKeepsTheSelectedCityVisibleAndReportsTheFailure() {
        let store = FailingHistoryStore()
        let model = makeModel(store: store)
        model.remember(city)

        XCTAssertEqual(model.history, [city])
        XCTAssertNotNil(model.historyMessage)
        model.retryHistory()
        XCTAssertEqual(model.history, [city])
        XCTAssertNotNil(model.historyMessage)
    }

    private func makeModel(
        repository: any CitySearching = SampleWeatherRepository(),
        store: any SearchHistoryReading & SearchHistoryWriting = MemorySearchHistoryStore(),
        delay: @escaping @Sendable () async throws -> Void = {}
    ) -> SearchViewModel {
        SearchViewModel(
            searchCities: SearchCitiesUseCase(repository: repository),
            loadHistory: LoadSearchHistoryUseCase(repository: store),
            rememberCity: RememberCityUseCase(reader: store, writer: store), searchDelay: delay
        )
    }
}

private actor SearchStub: CitySearching {
    private var cities: [City]
    private var failure: WeatherFailure?
    private(set) var queries: [String] = []

    init(cities: [City] = [], failure: WeatherFailure? = nil) {
        self.cities = cities
        self.failure = failure
    }

    func searchCities(named query: String) async throws -> [City] {
        queries.append(query)
        if let failure { throw failure }
        return cities
    }

    func setResult(_ cities: [City]) {
        self.cities = cities
        failure = nil
    }
}

private actor SearchDelayGate {
    private var pending: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?

    func pause() async {
        await withCheckedContinuation { continuation in
            pending = continuation
            waiter?.resume()
            waiter = nil
        }
    }

    func waitUntilStarted() async {
        guard pending == nil else { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func finish() {
        pending?.resume()
        pending = nil
    }
}

private actor GatedCitySearch: CitySearching {
    private var pending: CheckedContinuation<[City], Never>?
    private var waiter: CheckedContinuation<Void, Never>?

    func searchCities(named query: String) async throws -> [City] {
        await withCheckedContinuation { continuation in
            pending = continuation
            waiter?.resume()
            waiter = nil
        }
    }

    func waitUntilStarted() async {
        guard pending == nil else { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func finish(cities: [City]) {
        pending?.resume(returning: cities)
        pending = nil
    }
}
