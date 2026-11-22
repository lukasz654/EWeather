import Foundation
import Observation

enum SearchState: Equatable {
    case idle
    case loading
    case results([City])
    case empty
    case failed(WeatherFailure)
}

@Observable @MainActor
final class SearchViewModel {
    private(set) var query = ""
    private(set) var state: SearchState
    private(set) var history: [City] = []
    private(set) var validationMessage: String?
    private(set) var historyMessage: String?
    @ObservationIgnored private let searchCities: SearchCitiesUseCase
    @ObservationIgnored private let loadHistory: LoadSearchHistoryUseCase
    @ObservationIgnored private let rememberCity: RememberCityUseCase
    @ObservationIgnored private let searchDelay: @Sendable () async throws -> Void
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var unsavedCity: City?

    init(
        searchCities: SearchCitiesUseCase,
        loadHistory: LoadSearchHistoryUseCase,
        rememberCity: RememberCityUseCase,
        initialState: SearchState = .idle,
        searchDelay: @escaping @Sendable () async throws -> Void = { try await Task.sleep(for: .milliseconds(300)) }
    ) {
        self.searchCities = searchCities
        self.loadHistory = loadHistory
        self.rememberCity = rememberCity
        self.searchDelay = searchDelay
        self.state = initialState
        reloadHistory()
    }

    func updateQuery(_ input: String) {
        do {
            let normalized = try CityQuery.normalized(input)
            validationMessage = nil
            guard query != normalized else { return }
            // Invalidate immediately, before SwiftUI starts the task for the edited text.
            requestID = UUID()
            query = normalized
            state = .idle
        } catch {
            validationMessage = "Użyj tylko liter, spacji i myślnika. Cyfry i inne znaki są niedozwolone."
        }
    }

    func remember(_ city: City) {
        unsavedCity = city
        do {
            history = try rememberCity.execute(city: city)
            unsavedCity = nil
            historyMessage = nil
        } catch {
            // A history failure does not prevent opening the selected city.
            history = [city] + history.filter { $0.id != city.id }
            historyMessage = "Nie udało się zapisać historii. Ten wybór może zniknąć po zamknięciu aplikacji."
        }
    }

    func retryHistory() {
        if let city = unsavedCity { remember(city) } else { reloadHistory() }
    }

    private func reloadHistory() {
        do {
            history = try loadHistory.execute()
            historyMessage = nil
        } catch {
            historyMessage = "Nie udało się odczytać historii. Spróbuj ponownie."
        }
    }

    func search() async {
        guard !Task.isCancelled else { return }
        let currentID = UUID()
        requestID = currentID
        guard let text = try? CityQuery.searchTerm(query) else {
            state = .idle
            return
        }
        do {
            try await searchDelay()
            try Task.checkCancellation()
            guard requestID == currentID else { return }
            state = .loading
            let cities = try await searchCities.execute(query: text)
            try Task.checkCancellation()
            guard requestID == currentID else { return }
            state = cities.isEmpty ? .empty : .results(cities)
        } catch is CancellationError {
            if requestID == currentID { state = .idle }
        } catch {
            guard requestID == currentID, !Task.isCancelled else { return }
            state = .failed(error as? WeatherFailure ?? .unavailable)
        }
    }
}
