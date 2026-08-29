@testable import Weathervane
import XCTest

@MainActor
final class WeathervaneStateTests: XCTestCase {
    func testEmptySavedSelectionRemainsEmpty() {
        let cities = WeathervaneState.cities(
            forSavedCodes: [],
            availableCities: TimeZoneData.allTimezones
        )

        XCTAssertTrue(cities.isEmpty)
    }

    func testMissingSavedSelectionUsesDefaults() {
        let cities = WeathervaneState.cities(
            forSavedCodes: nil,
            availableCities: TimeZoneData.allTimezones
        )

        XCTAssertEqual(Set(cities.map(\.code)), Set(Constants.defaultCityCodes))
    }

    func testSelectionIsLimitedToMaximumCityCount() {
        let codes = TimeZoneData.allTimezones.map(\.code)
        let cities = WeathervaneState.cities(
            forSavedCodes: codes,
            availableCities: TimeZoneData.allTimezones
        )

        XCTAssertEqual(cities.count, Constants.maxCitiesToDisplay)
    }

    func testRemovingCityCancelsInFlightWeatherRequest() async throws {
        let service = SuspendingWeatherService()
        let defaultsName = "WeathervaneStateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let state = WeathervaneState(
            weatherService: service,
            userDefaults: defaults,
            startsBackgroundWork: false
        )
        defer {
            state.shutdown()
        }
        let city = City(
            code: "TST",
            timeZoneIdentifier: "UTC",
            displayName: "Test City"
        )

        state.updateSelectedCities([city])
        try await waitForStartedRequest(service)
        state.updateSelectedCities([])
        try await waitForCancellation(service)

        XCTAssertTrue(state.selectedCities.isEmpty)
        XCTAssertNil(state.getWeather(for: city))
    }

    private func waitForStartedRequest(_ service: SuspendingWeatherService) async throws {
        for _ in 0 ..< 100 {
            if await service.startedRequestCount == 1 {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Weather request did not start")
    }

    private func waitForCancellation(_ service: SuspendingWeatherService) async throws {
        for _ in 0 ..< 100 {
            if await service.cancellationCount == 1 {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Weather request was not cancelled")
    }
}

private actor SuspendingWeatherService: WeatherFetching {
    private(set) var startedRequestCount = 0
    private(set) var cancellationCount = 0

    func fetchWeather(cityName _: String, timeZone _: TimeZone) async throws -> WeatherData {
        startedRequestCount += 1
        do {
            try await Task.sleep(for: .seconds(60))
        } catch {
            cancellationCount += 1
            throw CancellationError()
        }
        throw NetworkError.invalidWeatherData
    }
}
