import XCTest
import WeatherDomain
import WeatherApplication

@MainActor
final class GetDailyForecastUseCaseTests: XCTestCase {
    private let city = City(id: 1, name: "Nowy Sącz", region: nil, country: "Polska", latitude: 49.62, longitude: 20.7, timeZoneIdentifier: "Europe/Warsaw")

    func testSelectsThreeDaysInCalendarOrderAcrossTheNewYear() async throws {
        let days = [day(2027, 1, 3), day(2026, 12, 31), day(2027, 1, 2), day(2027, 1, 1)]
        let result = try await GetDailyForecastUseCase(repository: DailyStub(days: days)).execute(city: city)
        XCTAssertEqual(result.map(\.day), [days[1].day, days[3].day, days[2].day])
    }

    func testPartialAndMissingDaysAreKeptWhenAnySelectedDayHasWeather() async throws {
        let missing = day(2026, 11, 23, temperature: nil)
        let available = day(2026, 11, 24, temperature: 0)
        let result = try await GetDailyForecastUseCase(repository: DailyStub(days: [missing, available])).execute(city: city)
        XCTAssertEqual(result, [missing, available])
        XCTAssertNil(result[0].minimumTemperature)
        XCTAssertEqual(result[1].minimumTemperature, 0)
    }

    func testMissingResultsAndEntirelyMissingWeatherAreEmpty() async throws {
        for days in [[], [day(2026, 11, 23, temperature: nil)]] {
            let result = try await GetDailyForecastUseCase(repository: DailyStub(days: days)).execute(city: city)
            XCTAssertEqual(result, [])
        }
    }

    func testWeatherOutsideTheThreeDayWindowDoesNotMakeItAvailable() async throws {
        let days = (23...26).map { day(2026, 11, $0, temperature: $0 == 26 ? 8 : nil) }
        let result = try await GetDailyForecastUseCase(repository: DailyStub(days: days)).execute(city: city)
        XCTAssertEqual(result, [])
    }

    func testKnownConditionsCanBeDisplayedWithoutTemperature() async throws {
        let forecast = DailyForecast(day: ForecastDay(year: 2026, month: 11, day: 23)!, minimumTemperature: nil, maximumTemperature: nil, maximumPrecipitationProbability: nil, condition: .overcast)
        let result = try await GetDailyForecastUseCase(repository: DailyStub(days: [forecast])).execute(city: city)
        XCTAssertEqual(result, [forecast])
    }

    func testDuplicateDayIdentifiersAreRejected() async {
        let forecast = day(2026, 11, 23)
        do {
            _ = try await GetDailyForecastUseCase(repository: DailyStub(days: [forecast, forecast])).execute(city: city)
            XCTFail("Expected a data error")
        } catch { XCTAssertEqual(error as? WeatherFailure, .invalidData) }
    }

    func testCancellationAfterAnEmptyProviderResultIsPreserved() async {
        let request = Task {
            try await GetDailyForecastUseCase(repository: CancellingDailyStub()).execute(city: city)
        }
        do { _ = try await request.value; XCTFail("Expected cancellation") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
    }

    func testAlreadyCancelledTaskDoesNotCallTheProvider() async {
        let repository = RecordingDailyStub()
        let request = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await GetDailyForecastUseCase(repository: repository).execute(city: city)
        }
        do { _ = try await request.value; XCTFail("Expected cancellation") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        let count = await repository.callCount
        XCTAssertEqual(count, 0)
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, temperature: Double? = 8) -> DailyForecast {
        DailyForecast(day: ForecastDay(year: year, month: month, day: day)!, minimumTemperature: temperature, maximumTemperature: nil, maximumPrecipitationProbability: nil, condition: .unknown)
    }
}

private struct DailyStub: DailyForecastProviding {
    let days: [DailyForecast]
    func dailyForecast(for city: City) async throws -> [DailyForecast] { days }
}

private struct CancellingDailyStub: DailyForecastProviding {
    func dailyForecast(for city: City) async throws -> [DailyForecast] {
        withUnsafeCurrentTask { $0?.cancel() }
        return []
    }
}

private actor RecordingDailyStub: DailyForecastProviding {
    private(set) var callCount = 0
    func dailyForecast(for city: City) async throws -> [DailyForecast] {
        callCount += 1
        return []
    }
}
