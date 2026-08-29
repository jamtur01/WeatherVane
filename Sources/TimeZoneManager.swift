import Foundation

enum TimeZoneManager {
    private static func sortByTimezoneOffset(_ cities: [City]) -> [City] {
        cities.sorted { city1, city2 in
            let offset1 = city1.timeZone.secondsFromGMT()
            let offset2 = city2.timeZone.secondsFromGMT()
            return offset1 < offset2
        }
    }

    static func getAllAvailableCities() -> [City] {
        sortByTimezoneOffset(TimeZoneData.allTimezones)
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
        sortByTimezoneOffset(cities)
    }
}
