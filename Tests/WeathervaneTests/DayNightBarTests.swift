@testable import Weathervane
import XCTest

final class DayNightBarTests: XCTestCase {
    func testNoonRemainsNoonOnSpringForwardDay() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let day = try localDate(
            year: 2026,
            month: 3,
            day: 8,
            hour: 0,
            timeZone: timeZone
        )

        let target = DayNightBar.targetDate(
            forFraction: 0.5,
            on: day,
            in: timeZone
        )

        XCTAssertEqual(localHour(for: target, timeZone: timeZone), 12)
    }

    func testNoonRemainsNoonOnFallBackDay() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let day = try localDate(
            year: 2026,
            month: 11,
            day: 1,
            hour: 0,
            timeZone: timeZone
        )

        let target = DayNightBar.targetDate(
            forFraction: 0.5,
            on: day,
            in: timeZone
        )

        XCTAssertEqual(localHour(for: target, timeZone: timeZone), 12)
    }

    private func localDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        timeZone: TimeZone
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return try XCTUnwrap(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )))
    }

    private func localHour(for date: Date, timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.component(.hour, from: date)
    }
}
