import Foundation

struct TimeZoneManager {
    private static var _sortedCities: [City]?
    private static let sortedCitiesQueue = DispatchQueue(
        label: "com.centraltime.sortedCities"
    )

    private static func sortByTimezoneOffset(_ cities: [City]) -> [City] {
        return cities.sorted { city1, city2 in
            let offset1 = city1.timeZone.secondsFromGMT()
            let offset2 = city2.timeZone.secondsFromGMT()
            return offset1 < offset2
        }
    }

    static func getAllAvailableCities() -> [City] {
        return sortedCitiesQueue.sync {
            if let cached = _sortedCities {
                return cached
            }

            let sorted = sortByTimezoneOffset(TimeZoneData.allTimezones)
            _sortedCities = sorted
            return sorted
        }
    }

    static func getDefaultCities() -> [City] {
        let defaultCodes = Constants.defaultCityCodes
        let allCities = getAllAvailableCities()
        let defaultCities = defaultCodes.compactMap { code in
            allCities.first { $0.code == code }
        }
        return sortCitiesByTimezone(defaultCities)
    }

    static func sortCitiesByTimezone(_ cities: [City]) -> [City] {
        return sortByTimezoneOffset(cities)
    }
}
