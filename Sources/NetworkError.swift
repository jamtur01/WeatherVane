import Foundation

enum NetworkError: LocalizedError {
    case invalidCityName
    case invalidResponse(statusCode: Int)
    case decodingError(Error)
    case invalidWeatherData
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCityName:
            return "Invalid city name"
        case .invalidResponse(let statusCode):
            return "Server error (code: \(statusCode))"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .invalidWeatherData:
            return "Invalid weather data format"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
