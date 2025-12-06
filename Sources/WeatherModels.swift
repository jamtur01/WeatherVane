// Weather models based on wttr.in JSON format
struct WeatherResponse: Codable {
    let currentCondition: [CurrentCondition]
    let nearestArea: [NearestArea]
    let weather: [Weather]
    
    enum CodingKeys: String, CodingKey {
        case currentCondition = "current_condition"
        case nearestArea = "nearest_area"
        case weather
    }
}

struct CurrentCondition: Codable {
    let tempC: String
    let weatherDesc: [WeatherDesc]
    let feelsLikeC: String
    let humidity: String
    let chanceOfRain: String?
    let windspeedKmph: String
    let winddir16Point: String
    let pressure: String
    let visibility: String
    
    enum CodingKeys: String, CodingKey {
        case tempC = "temp_C"
        case weatherDesc = "weatherDesc"
        case feelsLikeC = "FeelsLikeC"
        case humidity
        case chanceOfRain = "chanceofrain"
        case windspeedKmph
        case winddir16Point
        case pressure
        case visibility
    }
}

struct WeatherDesc: Codable {
    let value: String
}

struct NearestArea: Codable {
    let areaName: [AreaName]
}

struct AreaName: Codable {
    let value: String
}

struct Weather: Codable {
    let date: String
    let maxtempC: String
    let mintempC: String
    let hourly: [Hourly]
}

struct Hourly: Codable {
    let weatherDesc: [WeatherDesc]
}