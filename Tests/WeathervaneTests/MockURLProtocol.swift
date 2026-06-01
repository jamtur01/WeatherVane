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
    private static var stubs: [Stub] = []
    private static var count = 0

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

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        switch MockURLProtocol.nextStub() {
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .response(let status, let body):
            let response = HTTPURLResponse(
                url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}
