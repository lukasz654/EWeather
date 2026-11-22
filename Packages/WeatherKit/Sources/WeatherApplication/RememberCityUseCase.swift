import WeatherDomain
@MainActor
public struct RememberCityUseCase {
    private let reader: any SearchHistoryReading
    private let writer: any SearchHistoryWriting

    public init(reader: any SearchHistoryReading, writer: any SearchHistoryWriting) {
        self.reader = reader
        self.writer = writer
    }

    public func execute(city: City) throws -> [City] {
        let saved = try LoadSearchHistoryUseCase(repository: reader).execute()
        let updated = [city] + saved.filter { $0.id != city.id }
        try writer.saveHistory(updated)
        return updated
    }
}
