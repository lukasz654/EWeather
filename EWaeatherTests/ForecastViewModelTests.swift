import WeatherApplication
import WeatherDomain
import XCTest
@testable import EWaeather

@MainActor
final class ForecastViewModelTests: XCTestCase {
    private let city = SampleWeatherRepository.cities[0]

    func testLoadingIsVisibleAndDuplicateLoadsAreIgnored() async {
        let repository = GatedForecastRepository()
        let model = makeModel(repository)
        let request = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(0)
        XCTAssertEqual(model.state, .loading)

        await model.loadIfNeeded()
        await model.reload()
        let count = await repository.callCount
        XCTAssertEqual(count, 1)
        await repository.finish(0, with: SampleWeatherRepository.snapshot())
        await request.value
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast()))
    }

    func testLeavingTheScreenAllowsANewRequestAndIgnoresLateCompletion() async {
        let repository = GatedForecastRepository()
        let model = makeModel(repository)
        let first = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(0)

        first.cancel()
        model.cancelLoading()
        XCTAssertEqual(model.state, .idle)
        let second = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(1)
        await repository.finish(0, with: nil)
        await first.value
        XCTAssertEqual(model.state, .loading)

        await repository.finish(1, with: SampleWeatherRepository.snapshot())
        await second.value
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast()))
    }

    func testInvalidatedResponseCannotReplaceANewerForecastEvenWithoutCancellation() async {
        let repository = GatedForecastRepository()
        let model = makeModel(repository)
        let first = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(0)
        model.cancelLoading()
        let second = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(1)
        await repository.finish(1, with: SampleWeatherRepository.snapshot())
        await second.value

        await repository.finish(0, with: nil)
        await first.value
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast()))
    }

    func testAlreadyCancelledTaskDoesNotStartOrInvalidateLoading() async {
        let repository = GatedForecastRepository()
        let model = makeModel(repository)
        let active = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(0)
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await model.reload()
        }
        await cancelled.value
        XCTAssertEqual(model.state, .loading)
        let count = await repository.callCount
        XCTAssertEqual(count, 1)
        await repository.finish(0, with: nil)
        await active.value
        XCTAssertEqual(model.state, .empty)
    }

    func testEmptyAndFailureStatesCanBeRetriedByTheViewTask() async {
        for failure: WeatherFailure? in [nil, .offline, .unavailable, .invalidData] {
            let repository = RetryingForecastRepository(firstFailure: failure)
            let model = makeModel(repository)
            await model.loadIfNeeded()
            XCTAssertEqual(model.state, failure.map(ForecastState.failed) ?? .empty)

            await model.loadIfNeeded()
            XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast()))
            model.cancelLoading()
            XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast()))
        }
    }

    func testChangingRangeIgnoresAnOlderResponseWithoutCancellation() async {
        let repository = GatedForecastRepository()
        let model = makeModel(repository)
        let first = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(0)
        model.selectRange(.eight)
        XCTAssertEqual(model.state, .idle)
        let second = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(1)
        await repository.finish(1, with: SampleWeatherRepository.snapshot(range: .twelve))
        await second.value
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast(range: .eight)))
        await repository.finish(0, with: SampleWeatherRepository.snapshot())
        await first.value
        XCTAssertEqual(model.range, .eight)
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast(range: .eight)))
    }

    func testRepeatedRangeChoiceKeepsLoadedDataAndDoesNotRequestAgain() async {
        let repository = RecordingRangeRepository()
        let model = makeModel(repository)
        model.selectRange(.five)
        await model.loadIfNeeded()
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast(range: .five)))
        model.selectRange(.five)
        await model.loadIfNeeded()
        let firstRanges = await repository.ranges
        XCTAssertEqual(firstRanges, [.five])
        model.selectRange(.twelve)
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast(range: .five)))
        await model.loadIfNeeded()
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast(range: .twelve)))
        let finalRanges = await repository.ranges
        XCTAssertEqual(finalRanges, [.five, .twelve])
    }

    func testCancelledPreviousRangeDoesNotResetTheNewLoad() async {
        let repository = GatedForecastRepository()
        let model = makeModel(repository)
        let first = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(0)
        model.selectRange(.five)
        first.cancel()
        let second = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(1)
        await repository.finish(0, with: nil)
        await first.value
        XCTAssertEqual(model.state, .loading)
        XCTAssertEqual(model.range, .five)
        await repository.finish(1, with: SampleWeatherRepository.snapshot(range: .five))
        await second.value
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast(range: .five)))
    }

    func testRangeCanBeChangedAfterAFailure() async {
        let repository = RetryingForecastRepository(firstFailure: .offline)
        let model = makeModel(repository)
        await model.loadIfNeeded()
        XCTAssertEqual(model.state, .failed(.offline))
        model.selectRange(.twelve)
        await model.loadIfNeeded()
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast(range: .twelve)))
    }

    func testEveryRangeUpdateKeepsDataVisibleUntilTheNewResponseArrives() async {
        let repository = GatedForecastRepository()
        let model = makeLoadedModel(repository)
        let ranges: [HourlyForecastRange] = [.five, .eight, .twelve, .three]
        var displayedRange = HourlyForecastRange.three
        for (index, range) in ranges.enumerated() {
            let previousState = ForecastState.loaded(SampleWeatherRepository.forecast(range: displayedRange))
            model.selectRange(range)
            XCTAssertEqual(model.state, previousState)
            XCTAssertEqual(model.loadedRange, displayedRange)
            let request = Task { await model.loadIfNeeded() }
            await repository.waitUntilStarted(index)
            XCTAssertEqual(model.state, previousState)
            XCTAssertEqual(model.updateState, .loading)
            await model.loadIfNeeded()
            let count = await repository.callCount
            XCTAssertEqual(count, index + 1)

            await repository.finish(index, with: SampleWeatherRepository.snapshot(range: range))
            await request.value
            XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast(range: range)))
            XCTAssertEqual(model.loadedRange, range)
            XCTAssertEqual(model.updateState, .idle)
            displayedRange = range
        }
    }

    func testFailedOrEmptyRangeUpdatesKeepDataAndCanBeRetried() async {
        let cases: [(Result<WeatherSnapshot?, WeatherFailure>, ForecastUpdateState)] = [
            (.success(nil), .empty),
            (.failure(.offline), .failed(.offline)),
            (.failure(.unavailable), .failed(.unavailable)),
            (.failure(.invalidData), .failed(.invalidData))
        ]
        for (reply, expected) in cases {
            let repository = RangeUpdateRepository(replies: [reply, .success(SampleWeatherRepository.snapshot(range: .five))])
            let model = makeLoadedModel(repository)
            model.selectRange(.five)
            await model.loadIfNeeded()
            XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast()))
            XCTAssertEqual(model.loadedRange, .three)
            XCTAssertEqual(model.range, .five)
            XCTAssertEqual(model.updateState, expected)

            await model.loadIfNeeded()
            XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast(range: .five)))
            XCTAssertEqual(model.loadedRange, .five)
            XCTAssertEqual(model.updateState, .idle)
            let requestedRanges = await repository.ranges
            XCTAssertEqual(requestedRanges, [.five, .five])
        }
    }

    func testLeavingDuringAnUpdateKeepsDataAndAllowsThePendingRangeToReload() async {
        let repository = GatedForecastRepository()
        let model = makeLoadedModel(repository)
        model.selectRange(.five)
        let first = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(0)
        first.cancel()
        model.cancelLoading()
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast()))
        XCTAssertEqual(model.loadedRange, .three)
        XCTAssertEqual(model.updateState, .idle)

        let second = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(1)
        await repository.finish(0, with: nil)
        await first.value
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast()))
        XCTAssertEqual(model.updateState, .loading)
        await repository.finish(1, with: SampleWeatherRepository.snapshot(range: .five))
        await second.value
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast(range: .five)))
        XCTAssertEqual(model.loadedRange, .five)
        XCTAssertEqual(model.updateState, .idle)
    }

    func testReturningToTheDisplayedRangeIgnoresThePendingResponseWithoutARequest() async {
        let repository = GatedForecastRepository()
        let model = makeLoadedModel(repository)
        model.selectRange(.twelve)
        let request = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(0)
        model.selectRange(.three)
        await model.loadIfNeeded()
        await repository.finish(0, with: SampleWeatherRepository.snapshot(range: .twelve))
        await request.value
        let count = await repository.callCount
        XCTAssertEqual(count, 1)
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast()))
        XCTAssertEqual(model.range, .three)
        XCTAssertEqual(model.loadedRange, .three)
        XCTAssertEqual(model.updateState, .idle)
    }

    func testAnOlderUpdateFailureCannotReplaceANewerSuccessfulRange() async {
        let repository = GatedForecastRepository()
        let model = makeLoadedModel(repository)
        model.selectRange(.five)
        let first = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(0)
        model.selectRange(.eight)
        let second = Task { await model.loadIfNeeded() }
        await repository.waitUntilStarted(1)
        await repository.finish(1, with: SampleWeatherRepository.snapshot(range: .eight))
        await second.value
        await repository.fail(0, with: .offline)
        await first.value
        XCTAssertEqual(model.state, .loaded(SampleWeatherRepository.forecast(range: .eight)))
        XCTAssertEqual(model.loadedRange, .eight)
        XCTAssertEqual(model.updateState, .idle)
    }

    private func makeModel(_ repository: any ForecastProviding) -> ForecastViewModel {
        ForecastViewModel(city: city, getForecast: GetForecastUseCase(repository: repository))
    }

    private func makeLoadedModel(_ repository: any ForecastProviding) -> ForecastViewModel {
        ForecastViewModel(city: city, getForecast: GetForecastUseCase(repository: repository), initialState: .loaded(SampleWeatherRepository.forecast()))
    }
}

private actor GatedForecastRepository: ForecastProviding {
    private var pending: [Int: CheckedContinuation<WeatherSnapshot?, any Error>] = [:]
    private var waiters: [Int: CheckedContinuation<Void, Never>] = [:]
    private(set) var callCount = 0

    func forecast(for city: City, range: HourlyForecastRange) async throws -> WeatherSnapshot? {
        let index = callCount
        callCount += 1
        // Intentionally ignores cancellation to exercise protection against late responses.
        return try await withCheckedThrowingContinuation { continuation in
            pending[index] = continuation
            waiters.removeValue(forKey: index)?.resume()
        }
    }

    func waitUntilStarted(_ index: Int) async {
        guard pending[index] == nil else { return }
        await withCheckedContinuation { waiters[index] = $0 }
    }

    func finish(_ index: Int, with snapshot: WeatherSnapshot?) {
        pending.removeValue(forKey: index)?.resume(returning: snapshot)
    }

    func fail(_ index: Int, with failure: WeatherFailure) {
        pending.removeValue(forKey: index)?.resume(throwing: failure)
    }
}

private actor RangeUpdateRepository: ForecastProviding {
    private var replies: [Result<WeatherSnapshot?, WeatherFailure>]
    private(set) var ranges: [HourlyForecastRange] = []

    init(replies: [Result<WeatherSnapshot?, WeatherFailure>]) { self.replies = replies }

    func forecast(for city: City, range: HourlyForecastRange) async throws -> WeatherSnapshot? {
        ranges.append(range)
        return try replies.removeFirst().get()
    }
}

private actor RetryingForecastRepository: ForecastProviding {
    private let firstFailure: WeatherFailure?
    private var callCount = 0

    init(firstFailure: WeatherFailure?) { self.firstFailure = firstFailure }

    func forecast(for city: City, range: HourlyForecastRange) async throws -> WeatherSnapshot? {
        callCount += 1
        if callCount == 1 {
            if let firstFailure { throw firstFailure }
            return nil
        }
        return SampleWeatherRepository.snapshot(range: range)
    }
}

private actor RecordingRangeRepository: ForecastProviding {
    private(set) var ranges: [HourlyForecastRange] = []

    func forecast(for city: City, range: HourlyForecastRange) async throws -> WeatherSnapshot? {
        ranges.append(range)
        return SampleWeatherRepository.snapshot(timeZoneIdentifier: city.timeZoneIdentifier, range: range)
    }
}
