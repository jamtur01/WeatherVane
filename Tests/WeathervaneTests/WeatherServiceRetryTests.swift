import XCTest
@testable import Weathervane

final class WeatherServiceRetryTests: XCTestCase {
    private var validBody: Data { Data(WeatherFixture.json.utf8) }

    private func makeService(maxRetries: Int = 3) -> WeatherService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        // Zero base delay keeps retries instant for tests.
        return WeatherService(urlSession: session, maxRetries: maxRetries, retryBaseDelay: 0)
    }

    private func fetch(_ service: WeatherService) -> Result<WeatherData, Error> {
        let expectation = expectation(description: "fetch")
        var captured: Result<WeatherData, Error>!
        service.fetchWeather(cityName: "Chicago") { result in
            captured = result
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
        return captured
    }

    // MARK: - isRetryable

    func testServerAndRateLimitErrorsAreRetryable() {
        XCTAssertTrue(WeatherService.isRetryable(.invalidResponse(statusCode: 500)))
        XCTAssertTrue(WeatherService.isRetryable(.invalidResponse(statusCode: 503)))
        XCTAssertTrue(WeatherService.isRetryable(.invalidResponse(statusCode: 429)))
        XCTAssertTrue(WeatherService.isRetryable(.networkError(URLError(.timedOut))))
    }

    func testDeterministicErrorsAreNotRetryable() {
        XCTAssertFalse(WeatherService.isRetryable(.invalidResponse(statusCode: 404)))
        XCTAssertFalse(WeatherService.isRetryable(.invalidResponse(statusCode: 400)))
        XCTAssertFalse(WeatherService.isRetryable(.invalidCityName))
        XCTAssertFalse(WeatherService.isRetryable(.invalidWeatherData))
        XCTAssertFalse(WeatherService.isRetryable(.decodingError(URLError(.cannotParseResponse))))
    }

    // MARK: - retry behavior

    func testRecoversAfterTransient500() {
        MockURLProtocol.reset(with: [
            .response(status: 500, body: Data()),
            .response(status: 200, body: validBody),
        ])
        let result = fetch(makeService())
        XCTAssertNoThrow(try result.get())
        XCTAssertEqual(MockURLProtocol.requestCount, 2, "should retry once then succeed")
    }

    func testRecoversAfterTransientNetworkError() {
        MockURLProtocol.reset(with: [
            .failure(URLError(.networkConnectionLost)),
            .response(status: 200, body: validBody),
        ])
        let result = fetch(makeService())
        XCTAssertNoThrow(try result.get())
        XCTAssertEqual(MockURLProtocol.requestCount, 2)
    }

    func testGivesUpAfterMaxRetries() {
        MockURLProtocol.reset(with: [.response(status: 500, body: Data())])
        let result = fetch(makeService(maxRetries: 3))
        XCTAssertThrowsError(try result.get())
        XCTAssertEqual(MockURLProtocol.requestCount, 4, "1 initial + 3 retries")
    }

    func testDoesNotRetryNonRetryableStatus() {
        MockURLProtocol.reset(with: [.response(status: 404, body: Data())])
        let result = fetch(makeService())
        XCTAssertThrowsError(try result.get())
        XCTAssertEqual(MockURLProtocol.requestCount, 1, "404 must fail fast")
    }

    func testDoesNotRetryMalformedJSON() {
        MockURLProtocol.reset(with: [.response(status: 200, body: Data("not json".utf8))])
        let result = fetch(makeService())
        XCTAssertThrowsError(try result.get())
        XCTAssertEqual(MockURLProtocol.requestCount, 1, "decode failure is deterministic")
    }
}
