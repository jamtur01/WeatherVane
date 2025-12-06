import Foundation

class WeatherService {
    static let shared = WeatherService()

    private let urlSession: URLSession
    private let baseURL = "https://wttr.in"
    
    // Hourly forecast index representing midday (around noon)
    // wttr.in provides hourly data in 3-hour intervals starting at midnight
    // Index 4 represents approximately 12:00 PM, providing a representative
    // forecast for the overall day's conditions
    private let middayForecastIndex = 4

    // Simple weather emoji mappings
    private let weatherEmojis: [String: String] = [
        "Clear": "☀️", "Sunny": "🌞", "Partly cloudy": "⛅", "Cloudy": "☁️",
        "Overcast": "🌥️", "Mist": "🌫", "Fog": "🌁", "Light rain": "🌧",
        "Moderate rain": "🌧", "Heavy rain": "🌧💧", "Light snow": "❄️",
        "Moderate snow": "❄️🌨", "Heavy snow": "❄️❄️", "Blizzard": "❄️🌪", "Thunderstorm": "⛈️"
    ]

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        urlSession = URLSession(configuration: config)
    }

    func getTempEmoji(forTemp temp: Double) -> String {
        switch temp {
        case 35...: return "🔥"
        case 25..<35: return "🌞"
        case 15..<25: return "🌤️"
        case 5..<15: return "☁️"
        case 0..<5: return "❄️"
        default: return "⛄"
        }
    }

    /// Maps weather condition strings to emoji representations.
    /// The matching algorithm:
    /// 1. First tries exact match against the weatherEmojis dictionary
    /// 2. Falls back to partial matching, checking longer keys first to ensure
    ///    more specific conditions match before general ones (e.g., "Heavy rain shower"
    ///    should match "Heavy rain" before "rain")
    /// 3. Returns 🌡️ for unknown conditions
    ///
    /// Note: The wttr.in API typically returns conditions like "Partly cloudy",
    /// "Light rain shower", "Heavy snow", etc. The sorting by key length ensures
    /// that "Heavy rain" (10 chars) is checked before "rain" would be if it existed,
    /// preventing premature partial matches.
    func getWeatherEmoji(forCondition condition: String) -> String {
        // First try exact match
        if let emoji = weatherEmojis[condition] {
            return emoji
        }

        // Then try partial match with longer strings first to avoid incorrect matches
        let sortedKeys = weatherEmojis.keys.sorted { $0.count > $1.count }
        for key in sortedKeys {
            if condition.localizedCaseInsensitiveContains(key) {
                return weatherEmojis[key]!
            }
        }

        return "🌡️"
    }

    func fetchWeather(cityName: String, completion: @escaping (Result<WeatherData, Error>) -> Void) {
        guard !cityName.isEmpty,
              let encodedCity = cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/\(encodedCity)?format=j1") else {
            completion(.failure(NetworkError.invalidCityName))
            return
        }

        var request = URLRequest(url: url)
        request.addValue("curl/7.64.1", forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let task = urlSession.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(NetworkError.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                completion(.failure(NetworkError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)))
                return
            }

            // Check if response is an error message
            if let responseString = String(data: data, encoding: .utf8),
               responseString.lowercased().contains("unknown location") {
                print("❌ wttr.in returned 'unknown location' for query: \(cityName)")
                completion(.failure(NetworkError.invalidWeatherData))
                return
            }

            do {
                let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)

                guard let currentCondition = weatherResponse.currentCondition.first,
                      let weatherDesc = currentCondition.weatherDesc.first?.value,
                      let tempC = Double(currentCondition.tempC),
                      let feelsLike = Double(currentCondition.feelsLikeC),
                      let humidity = Int(currentCondition.humidity),
                      let areaName = weatherResponse.nearestArea.first?.areaName.first?.value else {
                    completion(.failure(NetworkError.invalidWeatherData))
                    return
                }

                let chanceOfRain = Int(currentCondition.chanceOfRain ?? "0") ?? 0

                // Get forecasts
                var forecasts: [Forecast] = []
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let todayDate = Calendar.current.startOfDay(for: Date())

                for forecastDay in weatherResponse.weather.prefix(3) {
                    // Parse the forecast date and compare as Date objects instead of strings
                    guard let forecastDate = dateFormatter.date(from: forecastDay.date),
                          forecastDate >= todayDate,
                          let maxTemp = Double(forecastDay.maxtempC),
                          let minTemp = Double(forecastDay.mintempC) else {
                        continue
                    }

                    let desc = forecastDay.hourly.count > self.middayForecastIndex ?
                        forecastDay.hourly[self.middayForecastIndex].weatherDesc.first?.value ?? "Unknown" : "Unknown"

                    forecasts.append(Forecast(
                        date: forecastDay.date,
                        maxTemp: maxTemp,
                        minTemp: minTemp,
                        description: desc
                    ))
                }

                let weatherData = WeatherData(
                    temperature: tempC,
                    feelsLike: feelsLike,
                    humidity: humidity,
                    chanceOfRain: chanceOfRain,
                    weatherDesc: weatherDesc,
                    areaName: areaName,
                    windSpeed: currentCondition.windspeedKmph,
                    windDirection: currentCondition.winddir16Point,
                    pressure: currentCondition.pressure,
                    visibility: currentCondition.visibility,
                    forecasts: forecasts,
                    isUsingLocation: false,
                    latitude: nil,
                    longitude: nil,
                    cityName: cityName
                )

                completion(.success(weatherData))
            } catch {
                print("❌ JSON decoding failed for '\(cityName)': \(error.localizedDescription)")
                // Log first 500 chars of response to help debug
                if let responseString = String(data: data, encoding: .utf8) {
                    let preview = responseString.prefix(500)
                    print("Response preview: \(preview)")
                }
                completion(.failure(NetworkError.decodingError(error)))
            }
        }

        task.resume()
    }
}
