struct WeatherData: Sendable {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let chanceOfRain: Int
    let weatherDesc: String
    let windSpeed: String
    let forecasts: [Forecast]
}

struct Forecast: Sendable {
    let date: String
    let maxTemp: Double
    let minTemp: Double
    let description: String
}
