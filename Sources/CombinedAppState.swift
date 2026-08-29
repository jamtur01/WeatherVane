import Foundation
import os
import SwiftUI

final class WeathervaneState: ObservableObject {
    private static let selectedCityCodesKey = "selectedCityCodes"
    private let logger = Logger(subsystem: "net.lovedthanlost.weathervane", category: "state")

    /// Time zone state
    @Published var selectedCities: [City] = []
    // Drives the rotating menu-bar title only; read directly (not via Combine),
    // so it is intentionally not @Published to avoid re-rendering the popover.
    var currentCityIndex = 0
    @Published var virtualNow: Date? = nil {
        didSet {
            if virtualNow == nil {
                startLiveTickTimer()
            } else {
                stopLiveTickTimer()
            }
        }
    }

    var effectiveNow: Date {
        virtualNow ?? Date()
    }

    var isVirtualTime: Bool {
        virtualNow != nil
    }

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
    private var liveTickTimer: Timer?
    private var isPopoverOpen = false

    // Per-city quick recovery after a transient failure (keyed by displayName).
    private var recoveryAttempts: [String: Int] = [:]
    private var recoveryWorkItems: [String: DispatchWorkItem] = [:]

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
        liveTickTimer?.invalidate()
        recoveryWorkItems.values.forEach { $0.cancel() }
    }

    // MARK: - Time Zone Methods

    private func startCityRotationTimer() {
        cityRotationTimer?.invalidate()
        cityRotationTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.cityRotationInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self, !self.selectedCities.isEmpty else { return }
            currentCityIndex = (currentCityIndex + 1) % selectedCities.count
        }
    }

    @MainActor
    func getTimeString(for city: City, shortFormat: Bool = false) -> String {
        let baseDate = effectiveNow
        return shortFormat
            ? DateFormatterManager.formatShortTime(for: city, date: baseDate, use24Hour: use24HourTime)
            : DateFormatterManager.formatLongTime(for: city, date: baseDate, use24Hour: use24HourTime)
    }

    @MainActor
    func setVirtualNow(_ date: Date) {
        virtualNow = date
    }

    @MainActor
    func adjustVirtualNow(by seconds: TimeInterval) {
        virtualNow = (virtualNow ?? Date()).addingTimeInterval(seconds)
    }

    @MainActor
    func resetTime() {
        virtualNow = nil
    }

    @MainActor
    func popoverDidOpen() {
        isPopoverOpen = true
        startLiveTickTimer()
    }

    @MainActor
    func popoverDidClose() {
        isPopoverOpen = false
        resetTime()
    }

    private func startLiveTickTimer() {
        guard isPopoverOpen, virtualNow == nil else {
            stopLiveTickTimer()
            return
        }
        liveTickTimer?.invalidate()
        liveTickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }
    }

    private func stopLiveTickTimer() {
        liveTickTimer?.invalidate()
        liveTickTimer = nil
    }

    func updateSelectedCities(_ cities: [City]) {
        cancelAllRecovery()
        selectedCities = TimeZoneManager.sortCitiesByTimezone(cities)
        currentCityIndex = 0
        pruneWeatherState(toKeep: Set(selectedCities.map(\.displayName)))
        saveCities()
        fetchAllWeather()
    }

    /// Drop cached weather/error/loading entries for cities no longer selected.
    private func pruneWeatherState(toKeep keys: Set<String>) {
        weatherDataByCity = weatherDataByCity.filter { keys.contains($0.key) }
        errorsByCity = errorsByCity.filter { keys.contains($0.key) }
        loadingCities = loadingCities.filter { keys.contains($0) }
    }

    private func cancelAllRecovery() {
        recoveryWorkItems.values.forEach { $0.cancel() }
        recoveryWorkItems.removeAll()
        recoveryAttempts.removeAll()
    }

    // MARK: - Persistence

    private func saveCities() {
        let codes = selectedCities.map(\.code)
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

    /// Primary query: the city's full name, which wttr.in resolves reliably.
    private func primaryQuery(for city: City) -> String {
        city.displayName
    }

    /// Fallback query: the name with spaces removed (e.g. "New York" -> "NewYork").
    /// Gives a distinct second query for multi-word names; equals the primary for
    /// single-word names, in which case the fallback request is skipped.
    private func fallbackQuery(for city: City) -> String {
        city.displayName.replacingOccurrences(of: " ", with: "")
    }

    func fetchWeather(for city: City) {
        let cityKey = city.displayName
        recoveryWorkItems[cityKey]?.cancel()
        recoveryWorkItems[cityKey] = nil

        loadingCities.insert(cityKey)
        errorsByCity.removeValue(forKey: cityKey)

        attemptFetch(for: city, query: primaryQuery(for: city), isFallback: false)
    }

    private func attemptFetch(for city: City, query: String, isFallback: Bool) {
        let cityKey = city.displayName
        weatherService.fetchWeather(cityName: query, timeZone: city.timeZone) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case let .success(data):
                    self.loadingCities.remove(cityKey)
                    self.weatherDataByCity[cityKey] = data
                    self.errorsByCity.removeValue(forKey: cityKey)
                    self.recoveryAttempts[cityKey] = nil
                case let .failure(error):
                    let fallback = self.fallbackQuery(for: city)
                    if !isFallback, fallback != query {
                        self.logger.warning("Weather fetch failed for '\(cityKey, privacy: .public)' using '\(query, privacy: .public)' (\(error.localizedDescription, privacy: .public)); trying fallback '\(fallback, privacy: .public)'")
                        self.attemptFetch(for: city, query: fallback, isFallback: true)
                    } else {
                        self.loadingCities.remove(cityKey)
                        self.errorsByCity[cityKey] = error.localizedDescription
                        self.logger.error("Weather fetch failed for '\(cityKey, privacy: .public)': \(error.localizedDescription, privacy: .public)")
                        self.scheduleRecovery(for: city, error: error)
                    }
                }
            }
        }
    }

    /// After a transient failure, re-poll just this city sooner than the next full
    /// poll, backing off and capping attempts before deferring to the normal cycle.
    private func scheduleRecovery(for city: City, error: Error) {
        let cityKey = city.displayName
        guard let networkError = error as? NetworkError,
              WeatherService.isRetryable(networkError) else {
            recoveryAttempts[cityKey] = nil
            return
        }

        let attempt = recoveryAttempts[cityKey] ?? 0
        guard attempt < Constants.maxWeatherRecoveryAttempts else { return }
        recoveryAttempts[cityKey] = attempt + 1

        let delay = Self.recoveryDelay(forAttempt: attempt)
        let work = DispatchWorkItem { [weak self] in
            self?.recoveryWorkItems[cityKey] = nil
            self?.fetchWeather(for: city)
        }
        recoveryWorkItems[cityKey] = work
        logger.info("Scheduling weather recovery for '\(cityKey, privacy: .public)' in \(delay, privacy: .public)s (attempt \(attempt + 1)/\(Constants.maxWeatherRecoveryAttempts))")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    static func recoveryDelay(forAttempt attempt: Int) -> TimeInterval {
        Constants.weatherRecoveryBaseDelay * pow(2.0, Double(attempt))
    }

    func getWeather(for city: City) -> WeatherData? {
        weatherDataByCity[city.displayName]
    }

    func isLoading(for city: City) -> Bool {
        loadingCities.contains(city.displayName)
    }

    func getError(for city: City) -> String? {
        errorsByCity[city.displayName]
    }
}
