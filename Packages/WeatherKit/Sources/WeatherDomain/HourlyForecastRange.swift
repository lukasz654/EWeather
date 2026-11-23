/// The supported number of future hourly steps shown in the app.
public enum HourlyForecastRange: Int, CaseIterable, Sendable {
    case three = 3
    case five = 5
    case eight = 8
    case twelve = 12
}
