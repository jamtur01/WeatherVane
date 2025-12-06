import Foundation

enum NetworkError: LocalizedError {
    case invalidCityName
    case noLocationOrCity
    case invalidURL
    case invalidResponse(statusCode: Int)
    case noData
    case decodingError(Error)
    case invalidWeatherData
    case networkError(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidCityName:
            return "Invalid city name"
        case .noLocationOrCity:
            return "No location or city provided"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse(let statusCode):
            return "Server error (code: \(statusCode))"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .invalidWeatherData:
            return "Invalid weather data format"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        }
    }
}
