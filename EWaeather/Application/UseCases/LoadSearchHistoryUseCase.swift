@MainActor
struct LoadSearchHistoryUseCase {
    private let repository: any SearchHistoryReading

    init(repository: any SearchHistoryReading) {
        self.repository = repository
    }

    func execute() throws -> [City] {
        var identifiers = Set<Int>()
        return try repository.loadHistory().filter { identifiers.insert($0.id).inserted }
    }
}
