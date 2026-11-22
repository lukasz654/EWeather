import Foundation

enum WeatherFormatting {
    static func temperature(_ value: Double?) -> String {
        guard let value else { return "Brak danych" }
        return value.formatted(.number.locale(Locale(identifier: "pl_PL")).precision(.fractionLength(0))) + "°C"
    }

    static func percent(_ value: Int?) -> String {
        value.map { "\($0)%" } ?? "Brak danych"
    }

    static func time(_ date: Date, timeZoneIdentifier: String) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: Locale(identifier: "pl_PL"), timeZone: cityTimeZone(timeZoneIdentifier)).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    static func dateAndTime(_ date: Date, timeZoneIdentifier: String) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .omitted, locale: Locale(identifier: "pl_PL"), timeZone: cityTimeZone(timeZoneIdentifier)).day().month(.abbreviated).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    static func interval(_ interval: DateInterval?, timeZoneIdentifier: String) -> String {
        guard let interval else { return "Przedział niedostępny" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = cityTimeZone(timeZoneIdentifier)
        let end = calendar.isDate(interval.start, inSameDayAs: interval.end)
            ? time(interval.end, timeZoneIdentifier: timeZoneIdentifier)
            : dateAndTime(interval.end, timeZoneIdentifier: timeZoneIdentifier)
        return "\(dateAndTime(interval.start, timeZoneIdentifier: timeZoneIdentifier)) – \(end)"
    }

    private static func cityTimeZone(_ identifier: String) -> TimeZone {
        TimeZone(identifier: identifier) ?? .gmt
    }
}
