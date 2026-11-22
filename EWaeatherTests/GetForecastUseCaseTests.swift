import XCTest
@testable import EWaeather

@MainActor
final class GetForecastUseCaseTests: XCTestCase {
    private let city = SampleWeatherRepository.cities[0]
    private let reference = Date(timeIntervalSince1970: 1_795_352_400)

    func testSelectsOnlyTheNext24HoursAndKeepsTheirOrder() async throws {
        let hours = (-1...26).reversed().map { hour in
            HourlyWeather(time: reference.addingTimeInterval(Double(hour) * 3600), temperature: Double(hour), precipitationProbability: hour == 1 ? 35 : 80)
        }
        let snapshot = WeatherSnapshot(updatedAt: reference, timeZoneIdentifier: "Europe/Warsaw", temperature: 8, cloudCover: 65, hours: hours)

        let forecast = try await GetForecastUseCase(repository: SnapshotRepository(value: snapshot)).execute(city: city)

        XCTAssertEqual(forecast?.hours.count, 24)
        XCTAssertEqual(forecast?.hours.first?.time, reference.addingTimeInterval(3600))
        XCTAssertEqual(forecast?.hours.last?.time, reference.addingTimeInterval(24 * 3600))
        XCTAssertEqual(forecast?.precipitationProbability, 35)
        XCTAssertEqual(forecast?.precipitationInterval, DateInterval(start: reference, duration: 3600))
    }

    func testMissingFirstHourValuesAreNotReplacedWithLaterWeather() async throws {
        let hours = [
            HourlyWeather(time: reference.addingTimeInterval(2700), temperature: nil, precipitationProbability: nil),
            HourlyWeather(time: reference.addingTimeInterval(6300), temperature: 9, precipitationProbability: 80)
        ]
        let snapshot = WeatherSnapshot(updatedAt: reference, timeZoneIdentifier: "Asia/Kolkata", temperature: nil, cloudCover: nil, hours: hours)

        let forecast = try await GetForecastUseCase(repository: SnapshotRepository(value: snapshot)).execute(city: city)

        XCTAssertNil(forecast?.temperature)
        XCTAssertNil(forecast?.cloudCover)
        XCTAssertNil(forecast?.precipitationProbability)
        XCTAssertNil(forecast?.hours.first?.temperature)
        XCTAssertEqual(forecast?.timeZoneIdentifier, "Asia/Kolkata")
        XCTAssertEqual(forecast?.precipitationInterval?.end, hours[0].time)
        XCTAssertEqual(forecast?.precipitationInterval?.duration, 3600)
    }

    func testCurrentConditionsCanExistWithoutFutureHours() async throws {
        let snapshot = WeatherSnapshot(updatedAt: reference, timeZoneIdentifier: "GMT", temperature: 0, cloudCover: 0, hours: [])
        let forecast = try await GetForecastUseCase(repository: SnapshotRepository(value: snapshot)).execute(city: city)

        XCTAssertEqual(forecast?.temperature, 0)
        XCTAssertEqual(forecast?.cloudCover, 0)
        XCTAssertEqual(forecast?.hours, [])
        XCTAssertNil(forecast?.precipitationInterval)
    }

    func testEmptyProviderResultStaysEmpty() async throws {
        let forecast = try await GetForecastUseCase(repository: SnapshotRepository(value: nil)).execute(city: city)
        XCTAssertNil(forecast)
    }

    func testPastValuesCannotMakeAnOtherwiseEmptyForecastLookAvailable() async throws {
        let snapshot = WeatherSnapshot(
            updatedAt: reference, timeZoneIdentifier: "GMT", temperature: nil, cloudCover: nil,
            hours: [HourlyWeather(time: reference.addingTimeInterval(-3600), temperature: 8, precipitationProbability: 20)]
        )
        let forecast = try await GetForecastUseCase(repository: SnapshotRepository(value: snapshot)).execute(city: city)
        XCTAssertNil(forecast)
    }

    func testRainIntervalAndHoursCrossLocalMidnight() async throws {
        let current = try date("2026-11-22T22:45:00Z")
        let midnight = try date("2026-11-22T23:00:00Z")
        let snapshot = WeatherSnapshot(
            updatedAt: current, timeZoneIdentifier: "Europe/Warsaw", temperature: 8, cloudCover: 65,
            hours: [HourlyWeather(time: midnight, temperature: 7, precipitationProbability: 30)]
        )
        let result = try await GetForecastUseCase(repository: SnapshotRepository(value: snapshot)).execute(city: city)
        let forecast = try XCTUnwrap(result)
        let interval = try XCTUnwrap(forecast.precipitationInterval)

        XCTAssertEqual(forecast.precipitationProbability, 30)
        XCTAssertEqual(interval.duration, 3600)
        XCTAssertEqual(WeatherFormatting.time(forecast.hours[0].time, timeZoneIdentifier: forecast.timeZoneIdentifier), "00:00")
        let label = WeatherFormatting.interval(interval, timeZoneIdentifier: forecast.timeZoneIdentifier)
        XCTAssertTrue(label.contains("22 lis"))
        XCTAssertTrue(label.contains("23 lis"))
        XCTAssertTrue(label.hasSuffix("00:00"))
    }

    func testAbsoluteHoursAreKeptAcrossTheSpringTimeChange() async throws {
        let firstHour = try date("2026-03-29T01:00:00Z")
        let snapshot = WeatherSnapshot(
            updatedAt: try date("2026-03-29T00:30:00Z"), timeZoneIdentifier: "Europe/Warsaw", temperature: 8, cloudCover: 65,
            hours: [
                HourlyWeather(time: firstHour, temperature: 7, precipitationProbability: 30),
                HourlyWeather(time: firstHour.addingTimeInterval(3600), temperature: 6, precipitationProbability: 40)
            ]
        )
        let result = try await GetForecastUseCase(repository: SnapshotRepository(value: snapshot)).execute(city: city)
        let forecast = try XCTUnwrap(result)

        XCTAssertEqual(forecast.hours.map { WeatherFormatting.time($0.time, timeZoneIdentifier: forecast.timeZoneIdentifier) }, ["03:00", "04:00"])
        XCTAssertEqual(forecast.precipitationInterval?.duration, 3600)
        XCTAssertEqual(forecast.hours[1].time.timeIntervalSince(forecast.hours[0].time), 3600)
    }

    func testRepeatedAutumnClockHoursRemainDistinctAndInChronologicalOrder() async throws {
        let firstHour = try date("2026-10-25T00:00:00Z")
        let snapshot = WeatherSnapshot(
            updatedAt: firstHour.addingTimeInterval(-900), timeZoneIdentifier: "Europe/Warsaw", temperature: 8, cloudCover: 65,
            hours: [
                HourlyWeather(time: firstHour, temperature: 7, precipitationProbability: 30),
                HourlyWeather(time: firstHour.addingTimeInterval(3600), temperature: 6, precipitationProbability: 40)
            ]
        )
        let result = try await GetForecastUseCase(repository: SnapshotRepository(value: snapshot)).execute(city: city)
        let forecast = try XCTUnwrap(result)

        XCTAssertEqual(forecast.hours.map { WeatherFormatting.time($0.time, timeZoneIdentifier: forecast.timeZoneIdentifier) }, ["02:00", "02:00"])
        XCTAssertNotEqual(forecast.hours[0].id, forecast.hours[1].id)
        XCTAssertEqual(forecast.hours[1].time.timeIntervalSince(forecast.hours[0].time), 3600)
        XCTAssertEqual(forecast.precipitationProbability, 30)
    }

    private func date(_ text: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: text))
    }

    func testCancellationIsPreservedEvenWhenProviderReturnsEmptyData() async {
        let task = Task {
            try await GetForecastUseCase(repository: CancellingSnapshotRepository()).execute(city: city)
        }
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
    }
}

private struct SnapshotRepository: ForecastProviding {
    let value: WeatherSnapshot?

    func forecast(for city: City) async throws -> WeatherSnapshot? { value }
}

private struct CancellingSnapshotRepository: ForecastProviding {
    func forecast(for city: City) async throws -> WeatherSnapshot? {
        withUnsafeCurrentTask { $0?.cancel() }
        return nil
    }
}
