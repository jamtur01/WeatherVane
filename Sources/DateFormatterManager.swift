import Foundation

/// Centralized date formatter management.
final class DateFormatterManager {

    private static let lock = NSLock()

    private static let shortFormatter12: DateFormatter = makeFormatter(Constants.shortTimeFormat12)
    private static let shortFormatter24: DateFormatter = makeFormatter(Constants.shortTimeFormat24)
    private static let longFormatter12: DateFormatter = makeFormatter(Constants.longTimeFormat12)
    private static let longFormatter24: DateFormatter = makeFormatter(Constants.longTimeFormat24)
    private static let rowDateFormatter: DateFormatter = makeFormatter(Constants.rowDateFormat)
    private static let bigTimeFormatter12: DateFormatter = makeFormatter(Constants.bigTimeFormat12)
    private static let bigTimeFormatter24: DateFormatter = makeFormatter(Constants.bigTimeFormat24)

    static let forecastDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private init() {}

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Constants.defaultLocaleIdentifier)
        formatter.dateFormat = format
        return formatter
    }

    static func formatShortTime(for city: City, date: Date = Date(), use24Hour: Bool = true) -> String {
        return format(date: date, timeZone: city.timeZone, using: use24Hour ? shortFormatter24 : shortFormatter12)
    }

    static func formatLongTime(for city: City, date: Date = Date(), use24Hour: Bool = true) -> String {
        return format(date: date, timeZone: city.timeZone, using: use24Hour ? longFormatter24 : longFormatter12)
    }

    static func formatBigTime(for city: City, date: Date = Date(), use24Hour: Bool = true) -> String {
        return format(date: date, timeZone: city.timeZone, using: use24Hour ? bigTimeFormatter24 : bigTimeFormatter12)
    }

    static func formatRowDate(for city: City, date: Date = Date()) -> String {
        return format(date: date, timeZone: city.timeZone, using: rowDateFormatter)
    }

    static func formatGMTOffset(for city: City, date: Date = Date()) -> String {
        let offset = city.timeZone.secondsFromGMT(for: date)
        let hours = offset / 3600
        let minutes = abs(offset % 3600) / 60
        if minutes == 0 {
            return "GMT\(hours >= 0 ? "+" : "")\(hours)"
        }
        return String(format: "GMT%+d:%02d", hours, minutes)
    }

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
        }
        lock.lock()
        defer { lock.unlock() }
        return dayOfWeekFormatter.string(from: date)
    }

    private static func format(date: Date, timeZone: TimeZone, using formatter: DateFormatter) -> String {
        lock.lock()
        defer { lock.unlock() }
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
