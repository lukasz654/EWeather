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
    var query = ""
    private(set) var state: SearchState
    let history: [City]
    @ObservationIgnored private let searchCities: SearchCitiesUseCase
    @ObservationIgnored private var requestID = UUID()

    init(searchCities: SearchCitiesUseCase, history: [City], initialState: SearchState = .idle) {
        self.searchCities = searchCities
        self.history = history
        self.state = initialState
    }

    func search() async {
        let currentID = UUID()
        requestID = currentID
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            state = .idle
            return
        }
        state = .loading
        do {
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
