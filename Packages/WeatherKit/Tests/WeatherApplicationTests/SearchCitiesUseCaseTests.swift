import WeatherApplication
import WeatherDomain
import XCTest

@MainActor
final class SearchCitiesUseCaseTests: XCTestCase {
    func testUseCaseDoesNotSendInvalidOrShortQueries() async throws {
        let repository = RecordingCitySearch()
        let useCase = SearchCitiesUseCase(repository: repository)
        _ = try await useCase.execute(query: " A-")
        do {
            _ = try await useCase.execute(query: "City2")
            XCTFail("Expected validation failure")
        } catch is CityQueryFailure {}
        let queries = await repository.queries
        XCTAssertEqual(queries, [])
    }

    func testUseCaseSendsNormalizedAndTrimmedText() async throws {
        let repository = RecordingCitySearch()
        _ = try await SearchCitiesUseCase(repository: repository).execute(query: "  Nowy Sa\u{0328}cz  ")
        let queries = await repository.queries
        XCTAssertEqual(queries, ["Nowy Sącz"])
    }
}

private actor RecordingCitySearch: CitySearching {
    private(set) var queries: [String] = []

    func searchCities(named query: String) async throws -> [City] {
        queries.append(query)
        return []
    }
}
