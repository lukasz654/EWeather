import XCTest
@testable import EWaeather

@MainActor
final class CityQueryTests: XCTestCase {
    func testPolishNamesSpacesHyphensAndOtherLettersAreAllowed() throws {
        for text in ["Bielsko-Biała", "Nowy Sącz", "Łódź", "Żółć", "São Paulo", "東京", "  Nowy Sącz  "] {
            XCTAssertEqual(try CityQuery.normalized(text), text)
        }
    }

    func testDigitsPunctuationAndWhitespaceOtherThanSpaceAreRejected() {
        for text in ["Warszawa1", "Łódź١", "City!", "City_Name", "City.Name", "City/Name", "O'City", "City–Name", "City\nName", "City\tName", "City\u{00A0}Name", "City☀️", "\u{0301}"] {
            XCTAssertThrowsError(try CityQuery.normalized(text)) { error in
                XCTAssertEqual(error as? CityQueryFailure, .invalidCharacters)
            }
        }
    }

    func testDecomposedPolishLettersAreNormalized() throws {
        XCTAssertEqual(try CityQuery.normalized("Sa\u{0328}cz"), "Sącz")
    }

    func testSearchNeedsTwoLettersRatherThanTwoCharacters() throws {
        for text in ["", " ", "-", "--", " A- "] {
            XCTAssertNil(try CityQuery.searchTerm(text))
        }
        XCTAssertEqual(try CityQuery.searchTerm("  Łó  "), "Łó")
    }

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
