import Foundation

@MainActor
struct AppComposition {
    private let repository = SampleWeatherRepository()

    func makeSearchModel(state: SearchState = .idle, history: [City] = SampleWeatherRepository.cities) -> SearchViewModel {
        SearchViewModel(searchCities: SearchCitiesUseCase(repository: repository), history: history, initialState: state)
    }

    func makeForecastModel(city: City, state: ForecastState = .idle) -> ForecastViewModel {
        ForecastViewModel(city: city, getForecast: GetForecastUseCase(repository: repository), initialState: state)
    }
}
