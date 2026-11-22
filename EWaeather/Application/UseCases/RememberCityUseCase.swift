import WeatherDomain
@MainActor
struct RememberCityUseCase {
    private let reader: any SearchHistoryReading
    private let writer: any SearchHistoryWriting

    init(reader: any SearchHistoryReading, writer: any SearchHistoryWriting) {
        self.reader = reader
        self.writer = writer
    }

    func execute(city: City) throws -> [City] {
        let saved = try LoadSearchHistoryUseCase(repository: reader).execute()
        let updated = [city] + saved.filter { $0.id != city.id }
        try writer.saveHistory(updated)
        return updated
    }
}
