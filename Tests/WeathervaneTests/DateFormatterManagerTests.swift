import XCTest
@testable import Weathervane

final class DateFormatterManagerTests: XCTestCase {
    private func city(_ identifier: String) -> City {
        City(code: "TST", timeZoneIdentifier: identifier)
    }

    func testGMTOffsetWholeHours() {
        XCTAssertEqual(DateFormatterManager.formatGMTOffset(for: city("UTC")), "GMT+0")
    }

    func testGMTOffsetHalfHour() {
        // India is a fixed +5:30 with no DST, so this is date-independent.
        XCTAssertEqual(DateFormatterManager.formatGMTOffset(for: city("Asia/Kolkata")), "GMT+5:30")
    }

    func testGMTOffsetQuarterHour() {
        // Nepal is a fixed +5:45.
        XCTAssertEqual(DateFormatterManager.formatGMTOffset(for: city("Asia/Kathmandu")), "GMT+5:45")
    }

    func testGMTOffsetNegative() {
        // Hawaii is a fixed -10 with no DST.
        XCTAssertEqual(DateFormatterManager.formatGMTOffset(for: city("Pacific/Honolulu")), "GMT-10")
    }

    func testForecastDateLabels() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let tomorrow = formatter.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)

        XCTAssertEqual(DateFormatterManager.formatForecastDate(today), "Today")
        XCTAssertEqual(DateFormatterManager.formatForecastDate(tomorrow), "Tomorrow")
    }

    func testForecastDateInvalidStringPassesThrough() {
        XCTAssertEqual(DateFormatterManager.formatForecastDate("not-a-date"), "not-a-date")
    }
}
