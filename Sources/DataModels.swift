struct WeatherData {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let chanceOfRain: Int
    let weatherDesc: String
    let areaName: String
    let windSpeed: String
    let windDirection: String
    let pressure: String
    let visibility: String
    let forecasts: [Forecast]
    let cityName: String?
}

struct Forecast {
    let date: String
    let maxTemp: Double
    let minTemp: Double
    let description: String
}
