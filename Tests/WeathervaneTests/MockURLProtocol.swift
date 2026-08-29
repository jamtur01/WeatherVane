import Foundation

/// A `URLProtocol` stub that replays a queued sequence of responses, so tests can
/// drive `WeatherService` without hitting the network. Each request consumes the
/// next stub; once the queue is exhausted the last stub repeats.
final class MockURLProtocol: URLProtocol {
    enum Stub {
        case response(status: Int, body: Data)
        case failure(Error)
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var stubs: [Stub] = [] // Access is serialized by `lock`.
    private nonisolated(unsafe) static var count = 0 // Access is serialized by `lock`.

    static func reset(with stubs: [Stub]) {
        lock.lock()
        defer { lock.unlock() }
        self.stubs = stubs
        count = 0
    }

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    private static func nextStub() -> Stub {
        lock.lock()
        defer { lock.unlock() }
        let index = min(count, stubs.count - 1)
        count += 1
        return stubs[index]
    }

    // URLProtocol requires a class override.
    // swiftlint:disable:next static_over_final_class
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    // URLProtocol requires a class override.
    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func stopLoading() {}

    override func startLoading() {
        switch MockURLProtocol.nextStub() {
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        case let .response(status, body):
            guard let url = request.url,
                  let response = HTTPURLResponse(
                      url: url,
                      statusCode: status,
                      httpVersion: nil,
                      headerFields: nil
                  ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}
