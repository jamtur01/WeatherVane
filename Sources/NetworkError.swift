import Foundation

enum NetworkError: LocalizedError, Sendable {
    case invalidCityName
    case invalidResponse(statusCode: Int)
    case decodingError(String)
    case invalidWeatherData
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidCityName:
            "Invalid city name"
        case let .invalidResponse(statusCode):
            "Server error (code: \(statusCode))"
        case let .decodingError(message):
            "Data parsing error: \(message)"
        case .invalidWeatherData:
            "Invalid weather data format"
        case let .networkError(message):
            "Network error: \(message)"
        }
    }
}
