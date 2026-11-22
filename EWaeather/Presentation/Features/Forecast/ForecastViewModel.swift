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
    @ObservationIgnored private let getForecast: GetForecastUseCase

    init(city: City, getForecast: GetForecastUseCase, initialState: ForecastState = .idle) {
        self.city = city
        self.getForecast = getForecast
        self.state = initialState
    }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        await reload()
    }

    func reload() async {
        guard state != .loading else { return }
        state = .loading
        do {
            let forecast = try await getForecast.execute(city: city)
            try Task.checkCancellation()
            state = forecast.map(ForecastState.loaded) ?? .empty
        } catch is CancellationError {
            state = .idle
        } catch {
            if Task.isCancelled { state = .idle; return }
            state = .failed(error as? WeatherFailure ?? .unavailable)
        }
    }
}
