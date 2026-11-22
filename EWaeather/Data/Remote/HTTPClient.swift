import Foundation

protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

enum HTTPFailure: Error, Equatable {
    case offline
    case transport
    case invalidResponse
    case status(Int, reason: String?)
    case invalidData

    var weatherFailure: WeatherFailure {
        switch self {
        case .offline: .offline
        case .invalidResponse, .invalidData: .invalidData
        case .transport, .status: .unavailable
        }
    }
}

struct HTTPClient: Sendable {
    private let transport: any HTTPTransport

    init(transport: any HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    func get<Response: Decodable & Sendable>(_ url: URL, as type: Response.Type) async throws -> Response {
        try Task.checkCancellation()
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await load(request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw HTTPFailure.invalidResponse }
        let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
        guard (200..<300).contains(response.statusCode), apiError?.error != true else {
            throw HTTPFailure.status(response.statusCode, reason: apiError?.reason)
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw HTTPFailure.invalidData
        }
    }

    private func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await transport.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw CancellationError()
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .internationalRoamingOff: throw HTTPFailure.offline
            default: throw HTTPFailure.transport
            }
        } catch {
            try Task.checkCancellation()
            throw HTTPFailure.transport
        }
    }
}

private struct APIErrorResponse: Decodable {
    let error: Bool
    let reason: String?
}
