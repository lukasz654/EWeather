import WeatherDomain
import XCTest

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

}
