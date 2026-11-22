import WeatherData
import XCTest
@testable import WeatherData

@MainActor
final class HTTPClientTests: XCTestCase {
    private let url = URL(string: "https://example.com/weather")!

    func testSuccessfulRequestUsesJSONAndReturnsDecodedData() async throws {
        let transport = StubHTTPTransport(body: #"{"value":7}"#)
        let response = try await HTTPClient(transport: transport).get(url, as: ValueResponse.self)

        XCTAssertEqual(response.value, 7)
        let sentRequest = await transport.lastRequest
        let request = try XCTUnwrap(sentRequest)
        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.timeoutInterval, 20)
    }

    func testHTTPFailuresKeepStatusAndServiceReason() async {
        for status in [400, 429, 500, 503] {
            let transport = StubHTTPTransport(status: status, body: #"{"error":true,"reason":"Service message"}"#)
            await assertFailure(.status(status, reason: "Service message"), transport: transport)
        }
    }

    func testNonJSONServerErrorIsStillAServiceFailure() async {
        await assertFailure(.status(502, reason: nil), transport: StubHTTPTransport(status: 502, body: "Bad gateway"))
    }

    func testErrorEnvelopeIsNotTreatedAsEmptySuccess() async {
        await assertFailure(.status(200, reason: "Invalid request"), transport: StubHTTPTransport(body: #"{"error":true,"reason":"Invalid request"}"#))
    }

    func testInvalidJSONAndWrongFieldTypesAreDataFailures() async {
        for body in ["not json", #"{"value":"seven"}"#, ""] {
            await assertFailure(.invalidData, transport: StubHTTPTransport(body: body))
        }
    }

    func testNonHTTPResponseIsRejected() async {
        await assertFailure(.invalidResponse, transport: StubHTTPTransport(nonHTTP: true))
    }

    func testConnectionFailuresAreDifferentFromTimeoutAndDNS() async {
        for code in [URLError.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff] {
            await assertFailure(.offline, transport: StubHTTPTransport(error: URLError(code)))
        }
        for code in [URLError.timedOut, .cannotFindHost, .cannotConnectToHost, .secureConnectionFailed] {
            await assertFailure(.transport, transport: StubHTTPTransport(error: URLError(code)))
        }
    }

    func testCancellationIsNotConvertedToAServiceFailure() async {
        for error: any Error in [CancellationError(), URLError(.cancelled)] {
            do {
                _ = try await HTTPClient(transport: StubHTTPTransport(error: error)).get(url, as: ValueResponse.self)
                XCTFail("Expected cancellation")
            } catch is CancellationError {
                // Cancellation remains a control-flow event for the screen model.
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testCancelledTaskDoesNotSendARequest() async {
        let transport = StubHTTPTransport(body: #"{"value":7}"#)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await HTTPClient(transport: transport).get(url, as: ValueResponse.self)
        }
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        let request = await transport.lastRequest
        XCTAssertNil(request)
    }

    private func assertFailure(_ expected: HTTPFailure, transport: StubHTTPTransport, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await HTTPClient(transport: transport).get(url, as: ValueResponse.self)
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? HTTPFailure, expected, file: file, line: line)
        }
    }
}

private struct ValueResponse: Decodable, Sendable {
    let value: Int
}
