// Helper structs for our app
public struct WeatherData {
    public let temperature: Double
    public let feelsLike: Double
    public let humidity: Int
    public let chanceOfRain: Int
    public let weatherDesc: String
    public let areaName: String
    public let windSpeed: String
    public let windDirection: String
    public let pressure: String
    public let visibility: String
    public let forecasts: [Forecast]
    public let isUsingLocation: Bool
    public let latitude: Double?
    public let longitude: Double?
    public let cityName: String?
    
    public init(temperature: Double, feelsLike: Double, humidity: Int, chanceOfRain: Int,
                weatherDesc: String, areaName: String, windSpeed: String, windDirection: String,
                pressure: String, visibility: String, forecasts: [Forecast], isUsingLocation: Bool,
                latitude: Double?, longitude: Double?, cityName: String?) {
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.humidity = humidity
        self.chanceOfRain = chanceOfRain
        self.weatherDesc = weatherDesc
        self.areaName = areaName
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.pressure = pressure
        self.visibility = visibility
        self.forecasts = forecasts
        self.isUsingLocation = isUsingLocation
        self.latitude = latitude
        self.longitude = longitude
        self.cityName = cityName
    }
}

public struct Forecast {
    public let date: String
    public let maxTemp: Double
    public let minTemp: Double
    public let description: String
    
    public init(date: String, maxTemp: Double, minTemp: Double, description: String) {
        self.date = date
        self.maxTemp = maxTemp
        self.minTemp = minTemp
        self.description = description
    }
}