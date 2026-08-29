/// Weather models based on wttr.in JSON format
struct WeatherResponse: Codable, Sendable {
    let currentCondition: [CurrentCondition]
    let weather: [Weather]

    enum CodingKeys: String, CodingKey {
        case currentCondition = "current_condition"
        case weather
    }
}

struct CurrentCondition: Codable, Sendable {
    let tempC: String
    let weatherDesc: [WeatherDesc]
    let feelsLikeC: String
    let humidity: String
    let windspeedKmph: String

    enum CodingKeys: String, CodingKey {
        case tempC = "temp_C"
        case weatherDesc
        case feelsLikeC = "FeelsLikeC"
        case humidity
        case windspeedKmph
    }
}

struct WeatherDesc: Codable, Sendable {
    let value: String
}

struct Weather: Codable, Sendable {
    let date: String
    let maxtempC: String
    let mintempC: String
    let hourly: [Hourly]
}

struct Hourly: Codable, Sendable {
    let weatherDesc: [WeatherDesc]
    let chanceOfRain: String?

    enum CodingKeys: String, CodingKey {
        case weatherDesc
        case chanceOfRain = "chanceofrain"
    }
}
