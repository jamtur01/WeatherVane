@testable import Weathervane
import XCTest

@MainActor
final class WeatherServiceRetryTests: XCTestCase {
    private func validBody() throws -> Data {
        try Data(WeatherFixture.json().utf8)
    }

    private func makeService(maxRetries: Int = 3) -> WeatherService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return WeatherService(
            urlSession: session,
            maxRetries: maxRetries,
            retryBaseDelay: 0
        )
    }

    private func fetch(_ service: WeatherService) async -> Result<WeatherData, Error> {
        do {
            return try await .success(service.fetchWeather(
                cityName: "Chicago",
                timeZone: .current
            ))
        } catch {
            return .failure(error)
        }
    }

    func testServerAndRateLimitErrorsAreRetryable() {
        XCTAssertTrue(WeatherService.isRetryable(.invalidResponse(statusCode: 500)))
        XCTAssertTrue(WeatherService.isRetryable(.invalidResponse(statusCode: 503)))
        XCTAssertTrue(WeatherService.isRetryable(.invalidResponse(statusCode: 429)))
        XCTAssertTrue(WeatherService.isRetryable(.networkError("timed out")))
    }

    func testDeterministicErrorsAreNotRetryable() {
        XCTAssertFalse(WeatherService.isRetryable(.invalidResponse(statusCode: 404)))
        XCTAssertFalse(WeatherService.isRetryable(.invalidResponse(statusCode: 400)))
        XCTAssertFalse(WeatherService.isRetryable(.invalidCityName))
        XCTAssertFalse(WeatherService.isRetryable(.invalidWeatherData))
        XCTAssertFalse(WeatherService.isRetryable(.decodingError("cannot parse")))
    }

    func testRecoversAfterTransient500() async throws {
        try MockURLProtocol.reset(with: [
            .response(status: 500, body: Data()),
            .response(status: 200, body: validBody())
        ])
        let result = await fetch(makeService())
        XCTAssertNoThrow(try result.get())
        XCTAssertEqual(MockURLProtocol.requestCount, 2)
    }

    func testRecoversAfterTransientNetworkError() async throws {
        try MockURLProtocol.reset(with: [
            .failure(URLError(.networkConnectionLost)),
            .response(status: 200, body: validBody())
        ])
        let result = await fetch(makeService())
        XCTAssertNoThrow(try result.get())
        XCTAssertEqual(MockURLProtocol.requestCount, 2)
    }

    func testGivesUpAfterMaxRetries() async {
        MockURLProtocol.reset(with: [.response(status: 500, body: Data())])
        let result = await fetch(makeService(maxRetries: 3))
        XCTAssertThrowsError(try result.get())
        XCTAssertEqual(MockURLProtocol.requestCount, 4)
    }

    func testDoesNotRetryNonRetryableStatus() async {
        MockURLProtocol.reset(with: [.response(status: 404, body: Data())])
        let result = await fetch(makeService())
        XCTAssertThrowsError(try result.get())
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    func testDoesNotRetryMalformedJSON() async {
        MockURLProtocol.reset(with: [
            .response(status: 200, body: Data("not json".utf8))
        ])
        let result = await fetch(makeService())
        XCTAssertThrowsError(try result.get())
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    func testDoesNotRetryCancelledRequest() async {
        MockURLProtocol.reset(with: [.failure(URLError(.cancelled))])

        let result = await fetch(makeService())

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }
}
