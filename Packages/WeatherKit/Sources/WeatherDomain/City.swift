import Foundation

public struct City: Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let region: String?
    public let country: String?
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String

    public init(id: Int, name: String, region: String?, country: String?, latitude: Double, longitude: Double, timeZoneIdentifier: String) {
        self.id = id
        self.name = name
        self.region = region
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}
