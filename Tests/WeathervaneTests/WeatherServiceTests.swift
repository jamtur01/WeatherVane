@testable import Weathervane
import XCTest

final class WeatherServiceTests: XCTestCase {
    private let service = WeatherService.shared

    // MARK: - getWeatherEmoji

    func testWeatherEmojiExactMatch() {
        XCTAssertEqual(service.getWeatherEmoji(forCondition: "Sunny"), "🌞")
        XCTAssertEqual(service.getWeatherEmoji(forCondition: "Overcast"), "🌥️")
    }

    func testWeatherEmojiPartialMatchIsCaseInsensitive() {
        // "Light rain shower" should match the "Light rain" key.
        XCTAssertEqual(service.getWeatherEmoji(forCondition: "Light rain shower"), "🌧")
        XCTAssertEqual(service.getWeatherEmoji(forCondition: "light rain"), "🌧")
    }

    func testWeatherEmojiPrefersLongerKeys() {
        // "Heavy snow" must win over "snow"-like shorter keys.
        XCTAssertEqual(service.getWeatherEmoji(forCondition: "Heavy snow"), "❄️❄️")
    }

    func testWeatherEmojiUnknownFallsBack() {
        XCTAssertEqual(service.getWeatherEmoji(forCondition: "Raining frogs"), "🌡️")
    }

    // MARK: - getTempEmoji

    func testTempEmojiBoundaries() {
        XCTAssertEqual(service.getTempEmoji(forTemp: 35), "🔥")
        XCTAssertEqual(service.getTempEmoji(forTemp: 34.9), "🌞")
        XCTAssertEqual(service.getTempEmoji(forTemp: 25), "🌞")
        XCTAssertEqual(service.getTempEmoji(forTemp: 24.9), "🌤️")
        XCTAssertEqual(service.getTempEmoji(forTemp: 0), "❄️")
        XCTAssertEqual(service.getTempEmoji(forTemp: -0.1), "⛄")
    }

    // MARK: - makeWeatherData

    /// `now` parsed in the current calendar so the forecast date filter is deterministic.
    private func date(_ yyyymmdd: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: yyyymmdd)!
    }

    func testMakeWeatherDataParsesCurrentConditions() throws {
        let response = try decode(WeatherFixture.json)
        let data = try XCTUnwrap(WeatherService.makeWeatherData(
            from: response, cityName: "London", now: date("2026-05-31")
        ))

        XCTAssertEqual(data.temperature, 18)
        XCTAssertEqual(data.feelsLike, 17)
        XCTAssertEqual(data.humidity, 60)
        XCTAssertEqual(data.weatherDesc, "Sunny")
        XCTAssertEqual(data.areaName, "London")
        XCTAssertEqual(data.windSpeed, "10")
    }

    func testMakeWeatherDataReadsChanceOfRainFromMiddayHourly() throws {
        // Regression guard: chance of rain comes from hourly[4], not current_condition.
        let response = try decode(WeatherFixture.json)
        let data = try XCTUnwrap(WeatherService.makeWeatherData(
            from: response, cityName: "London", now: date("2026-05-31")
        ))
        XCTAssertEqual(data.chanceOfRain, 40)
    }

    func testMakeWeatherDataFiltersPastForecastDays() throws {
        let response = try decode(WeatherFixture.json)
        let data = try XCTUnwrap(WeatherService.makeWeatherData(
            from: response, cityName: "London", now: date("2026-05-31")
        ))
        // Fixture has 2026-05-30 (past), 2026-05-31 (today), 2026-06-01 (future).
        XCTAssertEqual(data.forecasts.map(\.date), ["2026-05-31", "2026-06-01"])
        XCTAssertEqual(data.forecasts.first?.description, "Partly cloudy")
    }

    func testMakeForecastsUsesTrackedCityDate() throws {
        let response = try decode(WeatherFixture.json)
        let now = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-05-31T00:30:00Z")
        )
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))

        let forecasts = WeatherService.makeForecasts(
            from: response.weather,
            timeZone: timeZone,
            now: now
        )

        XCTAssertEqual(
            forecasts.map(\.date),
            ["2026-05-30", "2026-05-31", "2026-06-01"]
        )
    }

    func testMakeWeatherDataReturnsNilWhenCurrentConditionMissing() throws {
        let response = try decode(WeatherFixture.emptyCurrentConditionJSON)
        XCTAssertNil(WeatherService.makeWeatherData(from: response, cityName: "Nowhere"))
    }

    private func decode(_ json: String) throws -> WeatherResponse {
        try JSONDecoder().decode(WeatherResponse.self, from: Data(json.utf8))
    }
}
