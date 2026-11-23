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

    private func makeModel(_ repository: any ForecastProviding) -> ForecastViewModel {
        ForecastViewModel(city: city, getForecast: GetForecastUseCase(repository: repository))
    }
}

private actor GatedForecastRepository: ForecastProviding {
    private var pending: [Int: CheckedContinuation<WeatherSnapshot?, Never>] = [:]
    private var waiters: [Int: CheckedContinuation<Void, Never>] = [:]
    private(set) var callCount = 0

    func forecast(for city: City, range: HourlyForecastRange) async throws -> WeatherSnapshot? {
        let index = callCount
        callCount += 1
        // Intentionally ignores cancellation to exercise protection against late responses.
        return await withCheckedContinuation { continuation in
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
        return SampleWeatherRepository.snapshot()
    }
}
