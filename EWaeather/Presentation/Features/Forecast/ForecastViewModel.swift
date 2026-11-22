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
    @ObservationIgnored private let getForecast: GetForecastUseCase
    @ObservationIgnored private var requestID = UUID()

    init(city: City, getForecast: GetForecastUseCase, initialState: ForecastState = .idle) {
        self.city = city
        self.getForecast = getForecast
        self.state = initialState
    }

    func loadIfNeeded() async {
        switch state {
        case .loaded, .loading: return
        case .idle, .empty, .failed: await reload()
        }
    }

    func cancelLoading() {
        guard state == .loading else { return }
        requestID = UUID()
        state = .idle
    }

    func reload() async {
        guard !Task.isCancelled, state != .loading else { return }
        let currentID = UUID()
        requestID = currentID
        state = .loading
        do {
            let forecast = try await getForecast.execute(city: city)
            try Task.checkCancellation()
            guard requestID == currentID else { return }
            state = forecast.map(ForecastState.loaded) ?? .empty
        } catch is CancellationError {
            if requestID == currentID { state = .idle }
        } catch {
            guard requestID == currentID else { return }
            if Task.isCancelled { state = .idle; return }
            state = .failed(error as? WeatherFailure ?? .unavailable)
        }
    }
}
