import WeatherData
import WeatherApplication
import WeatherDomain
import Foundation

@MainActor
struct AppComposition {
    private let cityRepository: any CitySearching
    private let forecastRepository: any ForecastProviding
    private let dailyForecastRepository: any DailyForecastProviding
    private let historyStore: any SearchHistoryReading & SearchHistoryWriting

    init(
        cityRepository: any CitySearching = OpenMeteoCityRepository(),
        forecastRepository: any ForecastProviding = OpenMeteoForecastRepository(),
        dailyForecastRepository: any DailyForecastProviding = OpenMeteoDailyForecastRepository(),
        historyStore: any SearchHistoryReading & SearchHistoryWriting = UserDefaultsSearchHistoryStore()
    ) {
        self.cityRepository = cityRepository
        self.forecastRepository = forecastRepository
        self.dailyForecastRepository = dailyForecastRepository
        self.historyStore = historyStore
    }

    func makeSearchModel(state: SearchState = .idle) -> SearchViewModel {
        SearchViewModel(
            searchCities: SearchCitiesUseCase(repository: cityRepository),
            loadHistory: LoadSearchHistoryUseCase(repository: historyStore),
            rememberCity: RememberCityUseCase(reader: historyStore, writer: historyStore), initialState: state
        )
    }

    func makeForecastModel(city: City, state: ForecastState = .idle, range: HourlyForecastRange = .three) -> ForecastViewModel {
        ForecastViewModel(city: city, getForecast: GetForecastUseCase(repository: forecastRepository), initialState: state, range: range)
    }

    func makeDailyForecastModel(city: City, state: DailyForecastState = .idle) -> DailyForecastViewModel {
        DailyForecastViewModel(city: city, getDailyForecast: GetDailyForecastUseCase(repository: dailyForecastRepository), initialState: state)
    }
}
