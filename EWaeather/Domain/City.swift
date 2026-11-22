import Foundation

struct City: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let region: String?
    let country: String?
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String
}
