import XCTest
import WeatherDomain

final class ForecastDayTests: XCTestCase {
    func testRejectsImpossibleDatesAndAcceptsLeapDays() {
        XCTAssertNotNil(ForecastDay(year: 2024, month: 2, day: 29))
        for values in [(2025, 2, 29), (2026, 4, 31), (2026, 13, 1), (2026, 0, 1), (2026, 1, 0), (0, 1, 1), (10000, 1, 1)] {
            XCTAssertNil(ForecastDay(year: values.0, month: values.1, day: values.2))
        }
    }

    func testCalendarOrderAndIdentityCrossMonthsAndYears() throws {
        let last = try XCTUnwrap(ForecastDay(year: 2026, month: 12, day: 31))
        let first = try XCTUnwrap(ForecastDay(year: 2027, month: 1, day: 1))
        XCTAssertLessThan(last, first)
        XCTAssertEqual(Set([last, first, last]).count, 2)
        XCTAssertEqual([first, last].sorted(), [last, first])
    }

    func testDaysRemainDistinctAcrossBothClockChanges() throws {
        for values in [(3, 28), (10, 24)] {
            let days = try (values.1...values.1 + 2).map { day in
                try XCTUnwrap(ForecastDay(year: 2026, month: values.0, day: day))
            }
            XCTAssertEqual(Set(days).count, 3)
            XCTAssertEqual(days.sorted(), days)
        }
    }

    func testMissingValuesDoNotBecomeZeroOrClearWeather() throws {
        let day = try XCTUnwrap(ForecastDay(year: 2026, month: 11, day: 23))
        let missing = DailyForecast(day: day, minimumTemperature: nil, maximumTemperature: nil, maximumPrecipitationProbability: nil, condition: .unknown)
        let zero = DailyForecast(day: day, minimumTemperature: 0, maximumTemperature: nil, maximumPrecipitationProbability: 0, condition: .unknown)
        XCTAssertFalse(missing.hasWeatherData)
        XCTAssertNil(missing.minimumTemperature)
        XCTAssertTrue(zero.hasWeatherData)
        XCTAssertEqual(zero.maximumPrecipitationProbability, 0)
    }
}
