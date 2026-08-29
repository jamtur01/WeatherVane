import Foundation

struct City: Equatable, Hashable, Sendable {
    let code: String
    let timeZoneIdentifier: String
    let displayName: String
    let emoji: String

    private let _timeZone: TimeZone

    var timeZone: TimeZone {
        _timeZone
    }

    init(code: String, timeZoneIdentifier: String, displayName: String? = nil, emoji: String? = nil) {
        self.code = code
        self.timeZoneIdentifier = timeZoneIdentifier
        self.displayName = displayName ?? code
        self.emoji = emoji ?? "🌍"
        _timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }

    static func == (lhs: City, rhs: City) -> Bool {
        lhs.code == rhs.code
    }
}
