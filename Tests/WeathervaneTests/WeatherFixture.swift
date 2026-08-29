import Foundation

/// Builds wttr.in-shaped JSON for decoding tests.
enum WeatherFixture {
    private enum FixtureError: Error {
        case invalidUTF8
    }

    static func json() throws -> String {
        try makeJSON()
    }

    static func emptyCurrentConditionJSON() throws -> String {
        try makeJSON(currentCondition: [])
    }

    private static var defaultCurrent: [String: Any] {
        [
            "temp_C": "18",
            "FeelsLikeC": "17",
            "humidity": "60",
            "weatherDesc": [["value": "Sunny"]],
            "windspeedKmph": "10"
        ]
    }

    private static func day(_ date: String, max: String, min: String) -> [String: Any] {
        let descriptions = ["Clear", "Clear", "Sunny", "Sunny", "Partly cloudy"]
        let chanceOfRain = ["0", "0", "5", "10", "40"]
        let hourly = zip(descriptions, chanceOfRain).map { description, rain in
            ["weatherDesc": [["value": description]], "chanceofrain": rain] as [String: Any]
        }
        return ["date": date, "maxtempC": max, "mintempC": min, "hourly": hourly]
    }

    private static func makeJSON(currentCondition: [[String: Any]] = [defaultCurrent]) throws -> String {
        let root: [String: Any] = [
            "current_condition": currentCondition,
            "nearest_area": [["areaName": [["value": "London"]]]],
            "weather": [
                day("2026-05-30", max: "19", min: "11"),
                day("2026-05-31", max: "20", min: "12"),
                day("2026-06-01", max: "21", min: "13")
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: root)
        guard let json = String(data: data, encoding: .utf8) else {
            throw FixtureError.invalidUTF8
        }
        return json
    }
}
