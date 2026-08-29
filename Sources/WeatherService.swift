import Foundation
import os

protocol WeatherFetching: Sendable {
    func fetchWeather(cityName: String, timeZone: TimeZone) async throws -> WeatherData
}

struct WeatherService: WeatherFetching, Sendable {
    static let shared = WeatherService()

    private static let middayForecastIndex = 4
    private static let weatherEmojis: [String: String] = [
        "Clear": "☀️", "Sunny": "🌞", "Partly cloudy": "⛅", "Cloudy": "☁️",
        "Overcast": "🌥️", "Mist": "🌫", "Fog": "🌁", "Light rain": "🌧",
        "Moderate rain": "🌧", "Heavy rain": "🌧💧", "Light snow": "❄️",
        "Moderate snow": "❄️🌨", "Heavy snow": "❄️❄️", "Blizzard": "❄️🌪",
        "Thunderstorm": "⛈️"
    ]
    private static let conditionsBySpecificity = weatherEmojis.keys.sorted {
        $0.count > $1.count
    }

    private let urlSession: URLSession
    private let baseURL = "https://wttr.in"
    private let logger = Logger(
        subsystem: "net.lovedthanlost.weathervane",
        category: "weather"
    )
    private let maxRetries: Int
    private let retryBaseDelay: TimeInterval

    init(
        urlSession: URLSession = WeatherService.makeDefaultSession(),
        maxRetries: Int = 3,
        retryBaseDelay: TimeInterval = 1
    ) {
        precondition(maxRetries >= 0, "maxRetries must not be negative")
        precondition(retryBaseDelay >= 0, "retryBaseDelay must not be negative")
        self.urlSession = urlSession
        self.maxRetries = maxRetries
        self.retryBaseDelay = retryBaseDelay
    }

    func getWeatherEmoji(forCondition condition: String) -> String {
        if let emoji = Self.weatherEmojis[condition] {
            return emoji
        }
        for key in Self.conditionsBySpecificity
            where condition.localizedCaseInsensitiveContains(key) {
            if let emoji = Self.weatherEmojis[key] {
                return emoji
            }
        }
        return "🌡️"
    }

    func fetchWeather(cityName: String, timeZone: TimeZone) async throws -> WeatherData {
        let request = try makeRequest(cityName: cityName)
        var attempt = 0

        while true {
            do {
                let (data, response) = try await urlSession.data(for: request)
                return try parse(
                    data: data,
                    response: response,
                    cityName: cityName,
                    timeZone: timeZone
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                    throw CancellationError()
                }
                let networkError = normalizedNetworkError(error)
                guard attempt < maxRetries, Self.isRetryable(networkError) else {
                    throw networkError
                }
                try await waitBeforeRetry(
                    cityName: cityName,
                    error: networkError,
                    attempt: attempt
                )
                attempt += 1
            }
        }
    }

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

    static func makeWeatherData(
        from response: WeatherResponse,
        timeZone: TimeZone = .current,
        now: Date = Date()
    ) -> WeatherData? {
        guard let currentCondition = response.currentCondition.first,
              let weatherDesc = currentCondition.weatherDesc.first?.value,
              let tempC = Double(currentCondition.tempC),
              let feelsLike = Double(currentCondition.feelsLikeC),
              let humidity = Int(currentCondition.humidity) else {
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
            windSpeed: currentCondition.windspeedKmph,
            forecasts: makeForecasts(from: response.weather, timeZone: timeZone, now: now)
        )
    }

    static func makeForecasts(
        from weather: [Weather],
        timeZone: TimeZone,
        now: Date = Date()
    ) -> [Forecast] {
        let dateFormatter = makeAPIDateFormatter(timeZone: timeZone)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let todayDate = calendar.startOfDay(for: now)

        var forecasts: [Forecast] = []
        for forecastDay in weather {
            guard let forecast = makeForecast(
                from: forecastDay,
                todayDate: todayDate,
                dateFormatter: dateFormatter
            ) else {
                continue
            }
            forecasts.append(forecast)
            if forecasts.count == 3 {
                break
            }
        }
        return forecasts
    }

    private static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }

    private static func makeAPIDateFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func makeForecast(
        from day: Weather,
        todayDate: Date,
        dateFormatter: DateFormatter
    ) -> Forecast? {
        guard let date = dateFormatter.date(from: day.date),
              date >= todayDate,
              let maxTemp = Double(day.maxtempC),
              let minTemp = Double(day.mintempC) else {
            return nil
        }
        let description = day.hourly.count > middayForecastIndex
            ? day.hourly[middayForecastIndex].weatherDesc.first?.value ?? "Unknown"
            : "Unknown"
        return Forecast(
            date: day.date,
            maxTemp: maxTemp,
            minTemp: minTemp,
            description: description
        )
    }

    private func makeRequest(cityName: String) throws -> URLRequest {
        guard !cityName.isEmpty,
              var components = URLComponents(string: baseURL) else {
            throw NetworkError.invalidCityName
        }
        components.path = "/\(cityName)"
        components.queryItems = [URLQueryItem(name: "format", value: "j1")]
        guard let url = components.url else {
            throw NetworkError.invalidCityName
        }

        var request = URLRequest(url: url)
        request.addValue("Weathervane/1", forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func parse(
        data: Data,
        response: URLResponse,
        cityName: String,
        timeZone: TimeZone
    ) throws -> WeatherData {
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }
        if let responseString = String(data: data, encoding: .utf8),
           responseString.localizedCaseInsensitiveContains("unknown location") {
            logger.warning(
                "wttr.in returned an unknown location for \(cityName, privacy: .public)"
            )
            throw NetworkError.invalidWeatherData
        }

        do {
            let response = try JSONDecoder().decode(WeatherResponse.self, from: data)
            guard let weather = Self.makeWeatherData(
                from: response,
                timeZone: timeZone
            ) else {
                throw NetworkError.invalidWeatherData
            }
            return weather
        } catch let error as NetworkError {
            throw error
        } catch {
            let message = "JSON decoding failed for \(cityName): \(error.localizedDescription)"
            logger.error("\(message, privacy: .public)")
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }

    private func normalizedNetworkError(_ error: Error) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }
        return .networkError(error.localizedDescription)
    }

    private func waitBeforeRetry(
        cityName: String,
        error: NetworkError,
        attempt: Int
    ) async throws {
        let delay = retryBaseDelay * pow(2, Double(attempt))
        let message = "Retrying \(cityName) after \(error.localizedDescription); " +
            "attempt \(attempt + 2)/\(maxRetries + 1) in \(delay)s"
        logger.warning("\(message, privacy: .public)")
        guard delay > 0 else {
            try Task.checkCancellation()
            return
        }
        try await Task.sleep(for: .seconds(delay))
    }
}
