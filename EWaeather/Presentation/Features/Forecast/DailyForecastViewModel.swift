import Foundation
import Observation
import WeatherApplication
import WeatherDomain

enum DailyForecastState: Equatable {
    case idle
    case loading
    case loaded([DailyForecast])
    case empty
    case failed(WeatherFailure)
}

@Observable @MainActor
final class DailyForecastViewModel {
    private(set) var state: DailyForecastState
    @ObservationIgnored private let city: City
    @ObservationIgnored private let getDailyForecast: GetDailyForecastUseCase
    @ObservationIgnored private var requestID = UUID()

    init(city: City, getDailyForecast: GetDailyForecastUseCase, initialState: DailyForecastState = .idle) {
        self.city = city
        self.getDailyForecast = getDailyForecast
        state = initialState
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
            let days = try await getDailyForecast.execute(city: city)
            try Task.checkCancellation()
            guard requestID == currentID else { return }
            state = days.isEmpty ? .empty : .loaded(days)
        } catch is CancellationError {
            if requestID == currentID { state = .idle }
        } catch {
            guard requestID == currentID else { return }
            if Task.isCancelled { state = .idle; return }
            state = .failed(error as? WeatherFailure ?? .unavailable)
        }
    }
}
