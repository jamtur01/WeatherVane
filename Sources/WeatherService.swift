import Foundation
import os

class WeatherService {
    static let shared = WeatherService()

    private let urlSession: URLSession
    private let baseURL = "https://wttr.in"
    private let logger = Logger(subsystem: "net.lovedthanlost.weathervane", category: "weather")
    private let maxRetries: Int
    private let retryBaseDelay: TimeInterval

    /// Hourly forecast index representing midday (around noon)
    /// wttr.in provides hourly data in 3-hour intervals starting at midnight
    /// Index 4 represents approximately 12:00 PM, providing a representative
    /// forecast for the overall day's conditions
    private static let middayForecastIndex = 4

    /// Simple weather emoji mappings
    private let weatherEmojis: [String: String] = [
        "Clear": "☀️", "Sunny": "🌞", "Partly cloudy": "⛅", "Cloudy": "☁️",
        "Overcast": "🌥️", "Mist": "🌫", "Fog": "🌁", "Light rain": "🌧",
        "Moderate rain": "🌧", "Heavy rain": "🌧💧", "Light snow": "❄️",
        "Moderate snow": "❄️🌨", "Heavy snow": "❄️❄️", "Blizzard": "❄️🌪", "Thunderstorm": "⛈️"
    ]

    init(
        urlSession: URLSession = WeatherService.makeDefaultSession(),
        maxRetries: Int = 3,
        retryBaseDelay: TimeInterval = 1.0
    ) {
        self.urlSession = urlSession
        self.maxRetries = maxRetries
        self.retryBaseDelay = retryBaseDelay
    }

    private static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }

    func getTempEmoji(forTemp temp: Double) -> String {
        switch temp {
        case 35...: "🔥"
        case 25 ..< 35: "🌞"
        case 15 ..< 25: "🌤️"
        case 5 ..< 15: "☁️"
        case 0 ..< 5: "❄️"
        default: "⛄"
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

    func fetchWeather(
        cityName: String,
        timeZone: TimeZone,
        completion: @escaping (Result<WeatherData, Error>) -> Void
    ) {
        performFetch(
            cityName: cityName,
            timeZone: timeZone,
            attempt: 0,
            completion: completion
        )
    }

    /// wttr.in intermittently returns transient 5xx/429 errors for a given location.
    /// Returns `true` for errors worth retrying and `false` for deterministic ones
    /// (bad query, unknown location, malformed JSON) that will fail again identically.
    static func isRetryable(_ error: NetworkError) -> Bool {
        switch error {
        case .networkError:
            true
        case let .invalidResponse(statusCode):
            statusCode >= 500 || statusCode == 429
        case .invalidCityName, .invalidWeatherData, .decodingError:
            false
        }
    }

    private func performFetch(
        cityName: String,
        timeZone: TimeZone,
        attempt: Int,
        completion: @escaping (Result<WeatherData, Error>) -> Void
    ) {
        guard !cityName.isEmpty,
              let encodedCity = cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/\(encodedCity)?format=j1") else {
            completion(.failure(NetworkError.invalidCityName))
            return
        }

        var request = URLRequest(url: url)
        request.addValue("curl/7.64.1", forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let task = urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            switch parse(
                data: data,
                response: response,
                error: error,
                cityName: cityName,
                timeZone: timeZone
            ) {
            case let .success(weatherData):
                completion(.success(weatherData))
            case let .failure(networkError):
                guard attempt < maxRetries, Self.isRetryable(networkError) else {
                    completion(.failure(networkError))
                    return
                }
                let delay = retryBaseDelay * pow(2.0, Double(attempt))
                logger.warning("Retrying '\(cityName, privacy: .public)' after \(networkError.localizedDescription, privacy: .public) (attempt \(attempt + 2)/\(maxRetries + 1)) in \(delay, privacy: .public)s")
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.performFetch(
                        cityName: cityName,
                        timeZone: timeZone,
                        attempt: attempt + 1,
                        completion: completion
                    )
                }
            }
        }

        task.resume()
    }

    private func parse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        cityName: String,
        timeZone: TimeZone
    ) -> Result<WeatherData, NetworkError> {
        if let error {
            return .failure(.networkError(error))
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let data else {
            return .failure(.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0))
        }

        // Check if response is an error message
        if let responseString = String(data: data, encoding: .utf8),
           responseString.lowercased().contains("unknown location") {
            logger.warning("wttr.in returned 'unknown location' for query: \(cityName, privacy: .public)")
            return .failure(.invalidWeatherData)
        }

        do {
            let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)

            guard let weatherData = Self.makeWeatherData(
                from: weatherResponse,
                cityName: cityName,
                timeZone: timeZone
            ) else {
                return .failure(.invalidWeatherData)
            }

            return .success(weatherData)
        } catch {
            logger.error("JSON decoding failed for '\(cityName, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Response preview: \(responseString.prefix(500), privacy: .public)")
            }
            return .failure(.decodingError(error))
        }
    }

    /// Builds a `WeatherData` value from a decoded wttr.in response.
    ///
    /// Returns `nil` when required current-condition fields are missing or unparseable.
    /// Chance of rain is read from today's midday hourly entry, since wttr.in only
    /// reports it in the hourly forecast, not in `current_condition`.
    static func makeWeatherData(
        from response: WeatherResponse,
        cityName: String,
        timeZone: TimeZone = .current,
        now: Date = Date()
    ) -> WeatherData? {
        guard let currentCondition = response.currentCondition.first,
              let weatherDesc = currentCondition.weatherDesc.first?.value,
              let tempC = Double(currentCondition.tempC),
              let feelsLike = Double(currentCondition.feelsLikeC),
              let humidity = Int(currentCondition.humidity),
              let areaName = response.nearestArea.first?.areaName.first?.value else {
            return nil
        }

        let todayHourly = response.weather.first?.hourly ?? []
        let chanceOfRain = todayHourly.count > middayForecastIndex
            ? Int(todayHourly[middayForecastIndex].chanceOfRain ?? "") ?? 0
            : 0

        return WeatherData(
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
            forecasts: makeForecasts(from: response.weather, timeZone: timeZone, now: now),
            cityName: cityName
        )
    }

    /// Builds up to three days of forecasts, skipping any day before `now`.
    static func makeForecasts(
        from weather: [Weather],
        timeZone: TimeZone,
        now: Date = Date()
    ) -> [Forecast] {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let todayDate = calendar.startOfDay(for: now)

        var forecasts: [Forecast] = []
        for forecastDay in weather {
            guard let forecastDate = dateFormatter.date(from: forecastDay.date),
                  forecastDate >= todayDate,
                  let maxTemp = Double(forecastDay.maxtempC),
                  let minTemp = Double(forecastDay.mintempC) else {
                continue
            }

            let desc = forecastDay.hourly.count > middayForecastIndex
                ? forecastDay.hourly[middayForecastIndex].weatherDesc.first?.value ?? "Unknown"
                : "Unknown"

            forecasts.append(Forecast(
                date: forecastDay.date,
                maxTemp: maxTemp,
                minTemp: minTemp,
                description: desc
            ))
            if forecasts.count == 3 {
                break
            }
        }
        return forecasts
    }
}
