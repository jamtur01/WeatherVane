import Foundation

/// Thread-safe date formatting for city-local clocks and forecasts.
enum DateFormatting {
    private static let lock = NSLock()

    private static let shortFormatter12: DateFormatter = makeFormatter(Constants.shortTimeFormat12)
    private static let shortFormatter24: DateFormatter = makeFormatter(Constants.shortTimeFormat24)
    private static let longFormatter12: DateFormatter = makeFormatter(Constants.longTimeFormat12)
    private static let longFormatter24: DateFormatter = makeFormatter(Constants.longTimeFormat24)
    private static let rowDateFormatter: DateFormatter = makeFormatter(Constants.rowDateFormat)
    private static let bigTimeFormatter12: DateFormatter = makeFormatter(Constants.bigTimeFormat12)
    private static let bigTimeFormatter24: DateFormatter = makeFormatter(Constants.bigTimeFormat24)

    private static let forecastDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Constants.defaultLocaleIdentifier)
        formatter.dateFormat = format
        return formatter
    }

    static func formatShortTime(for city: City, date: Date = Date(), use24Hour: Bool = true) -> String {
        format(date: date, timeZone: city.timeZone, using: use24Hour ? shortFormatter24 : shortFormatter12)
    }

    static func formatLongTime(for city: City, date: Date = Date(), use24Hour: Bool = true) -> String {
        format(date: date, timeZone: city.timeZone, using: use24Hour ? longFormatter24 : longFormatter12)
    }

    static func formatBigTime(for city: City, date: Date = Date(), use24Hour: Bool = true) -> String {
        format(date: date, timeZone: city.timeZone, using: use24Hour ? bigTimeFormatter24 : bigTimeFormatter12)
    }

    static func formatRowDate(for city: City, date: Date = Date()) -> String {
        format(date: date, timeZone: city.timeZone, using: rowDateFormatter)
    }

    static func formatGMTOffset(for city: City, date: Date = Date()) -> String {
        let offset = city.timeZone.secondsFromGMT(for: date)
        let totalMinutes = offset / 60
        let sign = totalMinutes < 0 ? "-" : "+"
        let absMinutes = abs(totalMinutes)
        let hours = absMinutes / 60
        let minutes = absMinutes % 60
        if minutes == 0 {
            return "GMT\(sign)\(hours)"
        }
        return "GMT\(sign)\(hours):\(String(format: "%02d", minutes))"
    }

    static func formatForecastDate(
        _ dateString: String,
        timeZone: TimeZone = .current,
        now: Date = Date()
    ) -> String {
        lock.lock()
        forecastDateFormatter.timeZone = timeZone
        let date = forecastDateFormatter.date(from: dateString)
        lock.unlock()

        guard let date else { return dateString }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return dateString
        }

        if calendar.isDate(date, inSameDayAs: today) {
            return "Today"
        } else if calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        lock.lock()
        defer { lock.unlock() }
        dayOfWeekFormatter.timeZone = timeZone
        return dayOfWeekFormatter.string(from: date)
    }

    private static func format(date: Date, timeZone: TimeZone, using formatter: DateFormatter) -> String {
        lock.lock()
        defer { lock.unlock() }
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
