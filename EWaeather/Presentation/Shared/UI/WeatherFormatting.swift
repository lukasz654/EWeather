import WeatherDomain
import Foundation

enum WeatherFormatting {
    static func temperature(_ value: Double?) -> String {
        guard let value else { return "Brak danych" }
        return value.formatted(.number.locale(Locale(identifier: "pl_PL")).precision(.fractionLength(0))) + "°C"
    }

    static func percent(_ value: Int?) -> String {
        value.map { "\($0)%" } ?? "Brak danych"
    }

    static func time(_ date: Date, timeZoneIdentifier: String, includesUTCOffset: Bool = false) -> String {
        let text = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: Locale(identifier: "pl_PL"), timeZone: cityTimeZone(timeZoneIdentifier)).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        return text + (includesUTCOffset ? offsetLabel(date, timeZoneIdentifier: timeZoneIdentifier) : "")
    }

    static func dateAndTime(_ date: Date, timeZoneIdentifier: String, includesUTCOffset: Bool = false) -> String {
        let text = date.formatted(Date.FormatStyle(date: .omitted, time: .omitted, locale: Locale(identifier: "pl_PL"), timeZone: cityTimeZone(timeZoneIdentifier)).day().month(.abbreviated).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        return text + (includesUTCOffset ? offsetLabel(date, timeZoneIdentifier: timeZoneIdentifier) : "")
    }

    static func repeatedLocalTimes(in dates: [Date], timeZoneIdentifier: String) -> Set<Date> {
        let groups = Dictionary(grouping: dates) { dateAndTime($0, timeZoneIdentifier: timeZoneIdentifier) }
        return Set(groups.values.filter { $0.count > 1 }.flatMap { $0 })
    }

    static func interval(_ interval: DateInterval?, timeZoneIdentifier: String) -> String {
        guard let interval else { return "Przedział niedostępny" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = cityTimeZone(timeZoneIdentifier)
        let offsetChanges = calendar.timeZone.secondsFromGMT(for: interval.start) != calendar.timeZone.secondsFromGMT(for: interval.end)
        let end = calendar.isDate(interval.start, inSameDayAs: interval.end)
            ? time(interval.end, timeZoneIdentifier: timeZoneIdentifier, includesUTCOffset: offsetChanges)
            : dateAndTime(interval.end, timeZoneIdentifier: timeZoneIdentifier, includesUTCOffset: offsetChanges)
        return "\(dateAndTime(interval.start, timeZoneIdentifier: timeZoneIdentifier, includesUTCOffset: offsetChanges)) – \(end)"
    }

    private static func offsetLabel(_ date: Date, timeZoneIdentifier: String) -> String {
        let offset = cityTimeZone(timeZoneIdentifier).secondsFromGMT(for: date)
        let hours = abs(offset) / 3600
        let minutes = abs(offset) % 3600 / 60
        return String(format: " (UTC%@%02d:%02d)", offset >= 0 ? "+" : "−", hours, minutes)
    }

    private static func cityTimeZone(_ identifier: String) -> TimeZone {
        TimeZone(identifier: identifier) ?? .gmt
    }
}
