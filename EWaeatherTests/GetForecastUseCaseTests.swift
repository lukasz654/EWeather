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
