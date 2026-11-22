import XCTest
@testable import EWaeather

@MainActor
final class WeatherFormattingTests: XCTestCase {
    func testRepeatedClockHoursHaveDifferentUTCOffsets() throws {
        let first = try date("2026-10-25T00:00:00Z")
        let second = first.addingTimeInterval(3600)
        let ordinary = second.addingTimeInterval(3600)
        let repeated = WeatherFormatting.repeatedLocalTimes(in: [first, second, ordinary], timeZoneIdentifier: "Europe/Warsaw")

        XCTAssertEqual(repeated, Set([first, second]))
        XCTAssertTrue(WeatherFormatting.dateAndTime(first, timeZoneIdentifier: "Europe/Warsaw", includesUTCOffset: true).hasSuffix("02:00 (UTC+02:00)"))
        XCTAssertTrue(WeatherFormatting.dateAndTime(second, timeZoneIdentifier: "Europe/Warsaw", includesUTCOffset: true).hasSuffix("02:00 (UTC+01:00)"))
    }

    func testRainIntervalExplainsTheAutumnClockChange() throws {
        let start = try date("2026-10-25T00:00:00Z")
        let label = WeatherFormatting.interval(DateInterval(start: start, duration: 3600), timeZoneIdentifier: "Europe/Warsaw")

        XCTAssertTrue(label.contains("02:00 (UTC+02:00)"))
        XCTAssertTrue(label.hasSuffix("02:00 (UTC+01:00)"))
    }

    func testOrdinaryHoursDoNotNeedOffsetLabels() throws {
        let first = try date("2026-11-22T23:00:00Z")
        XCTAssertEqual(WeatherFormatting.repeatedLocalTimes(in: [first, first.addingTimeInterval(3600)], timeZoneIdentifier: "Europe/Warsaw"), [])
        XCTAssertFalse(WeatherFormatting.interval(DateInterval(start: first, duration: 3600), timeZoneIdentifier: "Europe/Warsaw").contains("UTC"))
    }

    func testOffsetFormattingSupportsFractionalAndNegativeTimeZones() {
        let epoch = Date(timeIntervalSince1970: 0)
        XCTAssertTrue(WeatherFormatting.time(epoch, timeZoneIdentifier: "Asia/Kolkata", includesUTCOffset: true).hasSuffix("(UTC+05:30)"))
        XCTAssertTrue(WeatherFormatting.time(epoch, timeZoneIdentifier: "America/New_York", includesUTCOffset: true).hasSuffix("(UTC−05:00)"))
    }

    private func date(_ text: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: text))
    }
}
