import XCTest
@testable import Weathervane

final class CityAndTimeZoneTests: XCTestCase {

    // MARK: - City

    func testCityDefaultsDisplayNameToCode() {
        let city = City(code: "ABC", timeZoneIdentifier: "UTC")
        XCTAssertEqual(city.displayName, "ABC")
        XCTAssertEqual(city.emoji, "🌍")
    }

    func testCityInvalidTimeZoneFallsBackToCurrent() {
        let city = City(code: "ZZZ", timeZoneIdentifier: "Not/AZone")
        XCTAssertEqual(city.timeZone.identifier, TimeZone.current.identifier)
    }

    func testCityEqualityAndHashingUseCodeOnly() {
        let a = City(code: "NYC", timeZoneIdentifier: "America/New_York", displayName: "New York")
        let b = City(code: "NYC", timeZoneIdentifier: "UTC", displayName: "Different")
        XCTAssertEqual(a, b)
        XCTAssertEqual(Set([a, b]).count, 1)
    }

    // MARK: - TimeZoneManager

    func testSortCitiesByTimezoneOrdersByOffsetAscending() {
        let unsorted = [
            City(code: "MEL", timeZoneIdentifier: "Australia/Melbourne"),
            City(code: "LAX", timeZoneIdentifier: "America/Los_Angeles"),
            City(code: "UTC", timeZoneIdentifier: "UTC"),
        ]
        let sorted = TimeZoneManager.sortCitiesByTimezone(unsorted)
        let offsets = sorted.map { $0.timeZone.secondsFromGMT() }
        XCTAssertEqual(offsets, offsets.sorted())
        XCTAssertEqual(sorted.first?.code, "LAX")
        XCTAssertEqual(sorted.last?.code, "MEL")
    }

    func testDefaultCitiesAreNonEmptyAndSorted() {
        let defaults = TimeZoneManager.getDefaultCities()
        XCTAssertFalse(defaults.isEmpty)
        let offsets = defaults.map { $0.timeZone.secondsFromGMT() }
        XCTAssertEqual(offsets, offsets.sorted())
    }
}
