import WeatherDomain
@MainActor
public struct LoadSearchHistoryUseCase {
    private let repository: any SearchHistoryReading

    public init(repository: any SearchHistoryReading) {
        self.repository = repository
    }

    public func execute() throws -> [City] {
        var identifiers = Set<Int>()
        return try repository.loadHistory().filter { identifiers.insert($0.id).inserted }
    }
}
