public struct DailyForecast: Identifiable, Equatable, Sendable {
    public var id: ForecastDay { day }
    public let day: ForecastDay
    public let minimumTemperature: Double?
    public let maximumTemperature: Double?
    public let maximumPrecipitationProbability: Int?
    public let condition: DailyWeatherCondition

    public init(
        day: ForecastDay,
        minimumTemperature: Double?,
        maximumTemperature: Double?,
        maximumPrecipitationProbability: Int?,
        condition: DailyWeatherCondition
    ) {
        self.day = day
        self.minimumTemperature = minimumTemperature
        self.maximumTemperature = maximumTemperature
        self.maximumPrecipitationProbability = maximumPrecipitationProbability
        self.condition = condition
    }

    public var hasWeatherData: Bool {
        minimumTemperature != nil || maximumTemperature != nil
            || maximumPrecipitationProbability != nil || condition != .unknown
    }
}
