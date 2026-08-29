@testable import Weathervane
import XCTest

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

    func testShortTimeHonorsTwelveAndTwentyFourHourFormats() throws {
        let date = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-05-31T13:05:00Z")
        )
        let utc = city("UTC")

        XCTAssertEqual(
            DateFormatterManager.formatShortTime(for: utc, date: date, use24Hour: true),
            "13:05"
        )
        XCTAssertEqual(
            DateFormatterManager.formatShortTime(for: utc, date: date, use24Hour: false),
            "1:05 PM"
        )
    }

    func testForecastDateLabels() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let tomorrowDate = try XCTUnwrap(
            Calendar.current.date(byAdding: .day, value: 1, to: Date())
        )
        let tomorrow = formatter.string(from: tomorrowDate)

        XCTAssertEqual(DateFormatterManager.formatForecastDate(today), "Today")
        XCTAssertEqual(DateFormatterManager.formatForecastDate(tomorrow), "Tomorrow")
    }

    func testForecastDateInvalidStringPassesThrough() {
        XCTAssertEqual(DateFormatterManager.formatForecastDate("not-a-date"), "not-a-date")
    }

    func testForecastDateLabelsUseTrackedCityTimeZone() throws {
        let now = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-05-31T00:30:00Z")
        )
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))

        XCTAssertEqual(
            DateFormatterManager.formatForecastDate(
                "2026-05-30",
                timeZone: timeZone,
                now: now
            ),
            "Today"
        )
    }
}
