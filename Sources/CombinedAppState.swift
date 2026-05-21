import SwiftUI
import Foundation

final class WeathervaneState: ObservableObject {
    private static let selectedCityCodesKey = "selectedCityCodes"

    // Time zone state
    @Published var selectedCities: [City] = []
    @Published var currentCityIndex = 0
    @Published var timeSliderOffset: TimeInterval = 0

    // Weather state - per city
    @Published var weatherDataByCity: [String: WeatherData] = [:]
    @Published var loadingCities: Set<String> = []
    @Published var errorsByCity: [String: String] = [:]

    @Published var use24HourTime: Bool = {
        if UserDefaults.standard.object(forKey: Constants.use24HourTimeKey) == nil {
            return Constants.defaultUse24Hour
        }
        return UserDefaults.standard.bool(forKey: Constants.use24HourTimeKey)
    }() {
        didSet {
            UserDefaults.standard.set(use24HourTime, forKey: Constants.use24HourTimeKey)
        }
    }

    private let weatherService = WeatherService.shared
    private var weatherTimer: Timer?
    private var cityRotationTimer: Timer?

    let allAvailableTimezones = TimeZoneManager.getAllAvailableCities()

    var currentDisplayCity: City? {
        guard !selectedCities.isEmpty else { return nil }
        return selectedCities[currentCityIndex]
    }

    init() {
        selectedCities = loadSavedCities()
        startCityRotationTimer()
        fetchAllWeather()
        startWeatherTimer()
    }

    deinit {
        weatherTimer?.invalidate()
        cityRotationTimer?.invalidate()
    }

    // MARK: - Time Zone Methods

    private func startCityRotationTimer() {
        cityRotationTimer?.invalidate()
        cityRotationTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.cityRotationInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self, !self.selectedCities.isEmpty else { return }
            self.currentCityIndex = (self.currentCityIndex + 1) % self.selectedCities.count
        }
    }

    @MainActor
    func getTimeString(for city: City, useSliderTime: Bool = false, shortFormat: Bool = false) -> String {
        let baseDate = useSliderTime ? Date().addingTimeInterval(timeSliderOffset) : Date()
        return shortFormat
            ? DateFormatterManager.formatShortTime(for: city, date: baseDate)
            : DateFormatterManager.formatLongTime(for: city, date: baseDate)
    }

    func previousHour() {
        timeSliderOffset -= Constants.secondsPerHour
    }

    func nextHour() {
        timeSliderOffset += Constants.secondsPerHour
    }

    func resetTime() {
        timeSliderOffset = 0
    }

    func updateSelectedCities(_ cities: [City]) {
        selectedCities = TimeZoneManager.sortCitiesByTimezone(cities)
        currentCityIndex = 0
        saveCities()
        fetchAllWeather()
    }

    // MARK: - Persistence

    private func saveCities() {
        let codes = selectedCities.map { $0.code }
        UserDefaults.standard.set(codes, forKey: Self.selectedCityCodesKey)
    }

    private func loadSavedCities() -> [City] {
        guard let codes = UserDefaults.standard.stringArray(
            forKey: Self.selectedCityCodesKey
        ) else {
            return TimeZoneManager.getDefaultCities()
        }
        let cities = codes.compactMap { code in
            allAvailableTimezones.first { $0.code == code }
        }
        guard !cities.isEmpty else {
            return TimeZoneManager.getDefaultCities()
        }
        return TimeZoneManager.sortCitiesByTimezone(cities)
    }

    // MARK: - Weather Methods

    private func startWeatherTimer() {
        weatherTimer?.invalidate()
        weatherTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.weatherUpdateInterval,
            repeats: true
        ) { [weak self] _ in
            self?.fetchAllWeather()
        }
    }

    /// Fetches weather data for all selected cities with staggered delays to avoid rate limiting.
    ///
    /// Note: This implementation uses sequential delays (1.0s between requests) to avoid
    /// overwhelming the wttr.in API. For users with many cities selected (up to 50 per
    /// Constants.maxCitiesToDisplay), this can result in significant delays:
    /// - 10 cities: ~10 second delay before all data is fetched
    /// - 25 cities: ~25 second delay
    /// - 50 cities: ~50 second delay
    ///
    /// Weather data will appear gradually as each request completes. This is preferable
    /// to being rate-limited or banned by the API, which would prevent all weather data
    /// from loading.
    func fetchAllWeather() {
        // Add delays between API calls to avoid rate limiting
        for (index, city) in selectedCities.enumerated() {
            let delay = Double(index) * Constants.weatherRequestDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.fetchWeather(for: city)
            }
        }
    }

    /// Get the best query string for a city's weather
    /// Some airport codes don't work well with wttr.in, so we use special mappings
    private func getWeatherQuery(for city: City, useCode: Bool) -> String {
        if useCode {
            // Special mappings for codes that don't work
            // Using simple city names that wttr.in can reliably parse
            switch city.code {
            case "NYC": return "NewYork"
            case "LAX": return "LosAngeles"
            case "CHI": return "Chicago"
            case "LHR": return "London"
            case "MEL": return "Melbourne"
            default: return city.code
            }
        }
        return city.displayName
    }

    func fetchWeather(for city: City) {
        let cityKey = city.displayName

        loadingCities.insert(cityKey)
        errorsByCity.removeValue(forKey: cityKey)

        // Try display name first
        let query = getWeatherQuery(for: city, useCode: false)
        weatherService.fetchWeather(cityName: query) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self.loadingCities.remove(cityKey)
                    self.weatherDataByCity[cityKey] = data
                    self.errorsByCity.removeValue(forKey: cityKey)
                case .failure(let initialError):
                    // Try fallback query
                    let fallbackQuery = self.getWeatherQuery(for: city, useCode: true)
                    print("⚠️ Weather fetch failed for '\(city.displayName)' using query '\(query)' (error: \(initialError.localizedDescription))")
                    print("🔄 Trying fallback query: '\(fallbackQuery)'")

                    self.weatherService.fetchWeather(cityName: fallbackQuery) { [weak self] fallbackResult in
                        guard let self = self else { return }

                        DispatchQueue.main.async {
                            self.loadingCities.remove(cityKey)

                            switch fallbackResult {
                            case .success(let data):
                                self.weatherDataByCity[cityKey] = data
                                self.errorsByCity.removeValue(forKey: cityKey)
                                print("✅ Fallback successful for '\(city.displayName)' using query '\(fallbackQuery)'")
                            case .failure(let error):
                                self.errorsByCity[cityKey] = error.localizedDescription
                                print("❌ Both fetch attempts failed for '\(city.displayName)':")
                                print("   First attempt ('\(query)'): \(initialError.localizedDescription)")
                                print("   Second attempt ('\(fallbackQuery)'): \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
    }

    func getWeather(for city: City) -> WeatherData? {
        return weatherDataByCity[city.displayName]
    }

    func isLoading(for city: City) -> Bool {
        return loadingCities.contains(city.displayName)
    }

    func getError(for city: City) -> String? {
        return errorsByCity[city.displayName]
    }
}
