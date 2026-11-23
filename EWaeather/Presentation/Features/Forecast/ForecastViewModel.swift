import WeatherApplication
import WeatherDomain
import Foundation
import Observation

enum ForecastState: Equatable {
    case idle
    case loading
    case loaded(Forecast)
    case empty
    case failed(WeatherFailure)
}

@Observable @MainActor
final class ForecastViewModel {
    let city: City
    private(set) var state: ForecastState
    private(set) var range: HourlyForecastRange
    private(set) var loadedRange: HourlyForecastRange?
    private(set) var updateState: ForecastUpdateState = .idle
    @ObservationIgnored private let getForecast: GetForecastUseCase
    @ObservationIgnored private var requestID = UUID()

    init(city: City, getForecast: GetForecastUseCase, initialState: ForecastState = .idle, range: HourlyForecastRange = .three) {
        self.city = city
        self.getForecast = getForecast
        self.state = initialState
        self.range = range
        if case .loaded = initialState { self.loadedRange = range }
    }

    func selectRange(_ range: HourlyForecastRange) {
        guard self.range != range else { return }
        requestID = UUID()
        self.range = range
        updateState = .idle
        if case .loaded = state { return }
        state = .idle
    }

    func loadIfNeeded() async {
        if case .loaded = state, loadedRange == range, updateState == .idle { return }
        await reload()
    }

    func cancelLoading() {
        guard isLoading else { return }
        requestID = UUID()
        finishCancellation()
    }

    func reload() async {
        guard !Task.isCancelled, !isLoading else { return }
        let currentID = UUID()
        let requestedRange = range
        requestID = currentID
        if case .loaded = state {
            updateState = .loading
        } else {
            state = .loading
        }
        do {
            let forecast = try await getForecast.execute(city: city, range: requestedRange)
            try Task.checkCancellation()
            guard requestID == currentID else { return }
            if let forecast {
                state = .loaded(forecast)
                loadedRange = requestedRange
                updateState = .idle
            } else if case .loaded = state {
                updateState = .empty
            } else {
                state = .empty
            }
        } catch {
            guard requestID == currentID else { return }
            if error is CancellationError || Task.isCancelled {
                finishCancellation()
                return
            }
            let failure = error as? WeatherFailure ?? .unavailable
            if case .loaded = state {
                updateState = .failed(failure)
            } else {
                state = .failed(failure)
            }
        }
    }

    private var isLoading: Bool {
        state == .loading || updateState == .loading
    }

    private func finishCancellation() {
        if state == .loading { state = .idle }
        updateState = .idle
    }
}
