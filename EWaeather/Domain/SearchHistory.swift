// History operations are synchronous on one actor so a read-modify-write cannot interleave.
@MainActor
protocol SearchHistoryReading {
    func loadHistory() throws -> [City]
}

@MainActor
protocol SearchHistoryWriting {
    func saveHistory(_ cities: [City]) throws
}

enum HistoryFailure: Error, Equatable {
    case invalidData
    case unavailable
}
