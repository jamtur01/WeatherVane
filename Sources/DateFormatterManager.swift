import Foundation

/// Centralized date formatter management to avoid creating multiple instances
/// and improve performance across the application
final class DateFormatterManager {

    private static let lock = NSLock()

    /// Shared long format date formatter (e.g., "Mon 3:45 PM")
    static let longFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Constants.defaultLocaleIdentifier)
        formatter.dateFormat = Constants.longTimeFormat
        return formatter
    }()

    /// Shared short format date formatter (e.g., "3:45 PM")
    static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Constants.defaultLocaleIdentifier)
        formatter.dateFormat = Constants.shortTimeFormat
        return formatter
    }()

    /// Shared formatter for forecast dates (yyyy-MM-dd format)
    static let forecastDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Shared formatter for day-of-week display (e.g., "Mon", "Tue")
    static let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private init() {}

    /// Thread-safe helper to set timezone on formatter and get formatted string
    static func formatTime(
        for city: City,
        using formatter: DateFormatter,
        date: Date = Date()
    ) -> String {
        lock.lock()
        defer { lock.unlock() }
        formatter.timeZone = city.timeZone
        return formatter.string(from: date)
    }

    static func formatShortTime(for city: City, date: Date = Date()) -> String {
        return formatTime(for: city, using: shortFormatter, date: date)
    }

    static func formatLongTime(for city: City, date: Date = Date()) -> String {
        return formatTime(for: city, using: longFormatter, date: date)
    }

    /// Format forecast date as "Today", "Tomorrow", or day of week (e.g., "Mon")
    static func formatForecastDate(_ dateString: String) -> String {
        lock.lock()
        let date = forecastDateFormatter.date(from: dateString)
        lock.unlock()

        guard let date = date else { return dateString }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        if calendar.isDate(date, inSameDayAs: today) {
            return "Today"
        } else if calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        } else {
            lock.lock()
            defer { lock.unlock() }
            return dayOfWeekFormatter.string(from: date)
        }
    }
}
