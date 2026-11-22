import Foundation
import WeatherData

/// Controlled responses, not recordings from the live API.
actor StubHTTPTransport: HTTPTransport {
    private let status: Int
    private let body: String
    private let error: (any Error)?
    private let nonHTTP: Bool
    private(set) var lastRequest: URLRequest?

    init(status: Int = 200, body: String = "{}", error: (any Error)? = nil, nonHTTP: Bool = false) {
        self.status = status
        self.body = body
        self.error = error
        self.nonHTTP = nonHTTP
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let error { throw error }
        guard let url = request.url else { throw URLError(.badURL) }
        let response: URLResponse
        if nonHTTP {
            response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        } else {
            response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        }
        return (Data(body.utf8), response)
    }
}
