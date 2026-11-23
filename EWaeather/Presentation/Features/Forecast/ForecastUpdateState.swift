import WeatherDomain

enum ForecastUpdateState: Equatable {
    case idle
    case loading
    case empty
    case failed(WeatherFailure)
}
