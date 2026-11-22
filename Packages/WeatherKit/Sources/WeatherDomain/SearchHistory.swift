// History operations are synchronous on one actor so a read-modify-write cannot interleave.
@MainActor
public protocol SearchHistoryReading {
    func loadHistory() throws -> [City]
}

@MainActor
public protocol SearchHistoryWriting {
    func saveHistory(_ cities: [City]) throws
}

public enum HistoryFailure: Error, Equatable {
    case invalidData
    case unavailable
}
