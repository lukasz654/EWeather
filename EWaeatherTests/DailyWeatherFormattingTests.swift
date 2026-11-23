import XCTest
import WeatherDomain
@testable import EWaeather

@MainActor
final class DailyWeatherFormattingTests: XCTestCase {
    func testLabelsKeepCalendarDatesAcrossBothClockChanges() throws {
        for (month, numbers) in [(3, [28, 29, 30]), (10, [24, 25, 26])] {
            let labels = try numbers.map { number in
                DailyWeatherFormatting.day(try XCTUnwrap(ForecastDay(year: 2026, month: month, day: number)))
            }
            XCTAssertEqual(Set(labels).count, 3)
            for (label, number) in zip(labels, numbers) {
                XCTAssertTrue(label.contains(String(number)), label)
            }
        }
    }

    func testLabelsCrossTheYearWithPolishMonthAndWeekdayNames() throws {
        let december = DailyWeatherFormatting.day(try XCTUnwrap(ForecastDay(year: 2026, month: 12, day: 31)))
        let january = DailyWeatherFormatting.day(try XCTUnwrap(ForecastDay(year: 2027, month: 1, day: 1)))
        XCTAssertTrue(december.contains("31"))
        XCTAssertTrue(december.contains("gru"))
        XCTAssertTrue(december.contains("czwartek"))
        XCTAssertTrue(january.contains("sty"))
        XCTAssertTrue(january.contains("piątek"))
    }

    func testUnknownConditionsDoNotLookLikeClearWeather() {
        XCTAssertEqual(DailyWeatherFormatting.description(.unknown), "Brak opisu pogody")
        XCTAssertEqual(DailyWeatherFormatting.systemImage(.unknown), "questionmark.circle")
        XCTAssertNotEqual(DailyWeatherFormatting.systemImage(.unknown), DailyWeatherFormatting.systemImage(.clearSky))
        for condition in DailyWeatherCondition.allCases {
            XCTAssertFalse(DailyWeatherFormatting.description(condition).isEmpty)
            XCTAssertFalse(DailyWeatherFormatting.systemImage(condition).isEmpty)
        }
    }

    func testDescriptionsDistinguishSeverityFreezingRainAndHail() {
        XCTAssertNotEqual(DailyWeatherFormatting.description(.lightRain), DailyWeatherFormatting.description(.heavyRain))
        XCTAssertTrue(DailyWeatherFormatting.description(.lightFreezingRain).contains("marznący"))
        XCTAssertTrue(DailyWeatherFormatting.description(.thunderstormWithHeavyHail).contains("gradem"))
        XCTAssertEqual(DailyWeatherFormatting.description(.heavyThunderstorm), "Silna burza")
    }
}
