import Foundation

enum CityCatalog {
    private static func sortByTimezoneOffset(_ cities: [City]) -> [City] {
        cities.sorted { city1, city2 in
            let offset1 = city1.timeZone.secondsFromGMT()
            let offset2 = city2.timeZone.secondsFromGMT()
            return offset1 < offset2
        }
    }

    static var allCities: [City] {
        sortByTimezoneOffset(TimeZoneData.allTimezones)
    }

    static var defaultCities: [City] {
        let defaultCodes = Constants.defaultCityCodes
        let defaultCities = defaultCodes.compactMap { code in
            allCities.first { $0.code == code }
        }
        return sortedByTimeZone(defaultCities)
    }

    static func sortedByTimeZone(_ cities: [City]) -> [City] {
        sortByTimezoneOffset(cities)
    }
}
