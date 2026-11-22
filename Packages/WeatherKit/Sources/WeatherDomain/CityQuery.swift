import Foundation

public enum CityQueryFailure: Error, Equatable {
    case invalidCharacters
}

public enum CityQuery {
    public static func normalized(_ input: String) throws -> String {
        let normalized = input.precomposedStringWithCanonicalMapping
        for character in normalized {
            if character == " " || character == "-" { continue }
            let scalars = Array(character.unicodeScalars)
            guard let first = scalars.first, isLetter(first), scalars.dropFirst().allSatisfy({
                isLetter($0) || [.nonspacingMark, .spacingMark, .enclosingMark].contains($0.properties.generalCategory)
            }) else { throw CityQueryFailure.invalidCharacters }
        }
        return normalized
    }

    public static func searchTerm(_ input: String) throws -> String? {
        let text = try normalized(input).trimmingCharacters(in: CharacterSet(charactersIn: " "))
        return text.filter(\.isLetter).count >= 2 ? text : nil
    }

    private static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        [.uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter]
            .contains(scalar.properties.generalCategory)
    }
}
