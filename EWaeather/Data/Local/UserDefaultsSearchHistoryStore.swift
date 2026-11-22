import Foundation

@MainActor
final class UserDefaultsSearchHistoryStore: SearchHistoryReading, SearchHistoryWriting {
    private let defaults: UserDefaults
    private let key = "searchHistory.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadHistory() throws -> [City] {
        guard defaults.object(forKey: key) != nil else { return [] }
        guard let data = defaults.data(forKey: key) else { throw HistoryFailure.invalidData }
        do {
            return try JSONDecoder().decode([StoredCity].self, from: data).map { try $0.city() }
        } catch {
            throw HistoryFailure.invalidData
        }
    }

    func saveHistory(_ cities: [City]) throws {
        do {
            let data = try JSONEncoder().encode(cities.map(StoredCity.init))
            defaults.set(data, forKey: key)
        } catch {
            throw HistoryFailure.unavailable
        }
    }
}

private struct StoredCity: Codable {
    let id: Int
    let name: String
    let region: String?
    let country: String?
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String

    init(_ city: City) {
        id = city.id
        name = city.name
        region = city.region
        country = city.country
        latitude = city.latitude
        longitude = city.longitude
        timeZoneIdentifier = city.timeZoneIdentifier
    }

    func city() throws -> City {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw HistoryFailure.invalidData
        }
        return City(id: id, name: name, region: region, country: country, latitude: latitude, longitude: longitude, timeZoneIdentifier: timeZoneIdentifier)
    }
}
