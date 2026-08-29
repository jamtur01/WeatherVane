import Foundation
import os
import SwiftUI

@MainActor
final class WeathervaneState: ObservableObject {
    private static let selectedCityCodesKey = "selectedCityCodes"

    @Published private(set) var selectedCities: [City]
    @Published private(set) var virtualNow: Date? {
        didSet {
            if virtualNow == nil {
                startLiveTickTimer()
            } else {
                stopLiveTickTimer()
            }
        }
    }

    @Published private(set) var weatherDataByCity: [String: WeatherData] = [:]
    @Published private(set) var loadingCities: Set<String> = []
    @Published private(set) var errorsByCity: [String: String] = [:]
    @Published var use24HourTime: Bool {
        didSet {
            userDefaults.set(use24HourTime, forKey: Constants.use24HourTimeKey)
        }
    }

    private(set) var currentCityIndex = 0
    let allAvailableTimezones: [City]

    var effectiveNow: Date {
        virtualNow ?? Date()
    }

    var isVirtualTime: Bool {
        virtualNow != nil
    }

    var currentDisplayCity: City? {
        guard selectedCities.indices.contains(currentCityIndex) else {
            return selectedCities.first
        }
        return selectedCities[currentCityIndex]
    }

    private let logger = Logger(
        subsystem: "net.lovedthanlost.weathervane",
        category: "state"
    )
    private let weatherService: any WeatherFetching
    private let userDefaults: UserDefaults
    private var weatherTimer: Timer?
    private var cityRotationTimer: Timer?
    private var liveTickTimer: Timer?
    private var isPopoverOpen = false
    private var weatherBatchTask: Task<Void, Never>?
    private var weatherTasks: [String: Task<Void, Never>] = [:]
    private var recoveryTasks: [String: Task<Void, Never>] = [:]
    private var recoveryAttempts: [String: Int] = [:]
    private var requestGenerations: [String: Int] = [:]

    init(
        weatherService: any WeatherFetching = WeatherService.shared,
        userDefaults: UserDefaults = .standard,
        startsBackgroundWork: Bool = true
    ) {
        self.weatherService = weatherService
        self.userDefaults = userDefaults
        allAvailableTimezones = TimeZoneManager.getAllAvailableCities()
        selectedCities = []
        virtualNow = nil
        use24HourTime = Self.loadTimeFormat(from: userDefaults)
        selectedCities = loadSavedCities()

        guard startsBackgroundWork else {
            return
        }
        startCityRotationTimer()
        fetchAllWeather()
        startWeatherTimer()
    }

    func shutdown() {
        weatherTimer?.invalidate()
        weatherTimer = nil
        cityRotationTimer?.invalidate()
        cityRotationTimer = nil
        liveTickTimer?.invalidate()
        liveTickTimer = nil
        cancelAllWeatherWork()
    }

    func getTimeString(for city: City, shortFormat: Bool = false) -> String {
        if shortFormat {
            return DateFormatterManager.formatShortTime(
                for: city,
                date: effectiveNow,
                use24Hour: use24HourTime
            )
        }
        return DateFormatterManager.formatLongTime(
            for: city,
            date: effectiveNow,
            use24Hour: use24HourTime
        )
    }

    func setVirtualNow(_ date: Date) {
        virtualNow = date
    }

    func resetTime() {
        virtualNow = nil
    }

    func popoverDidOpen() {
        isPopoverOpen = true
        startLiveTickTimer()
    }

    func popoverDidClose() {
        isPopoverOpen = false
        resetTime()
    }

    func updateSelectedCities(_ cities: [City]) {
        cancelAllWeatherWork()
        selectedCities = Array(
            TimeZoneManager.sortCitiesByTimezone(cities)
                .prefix(Constants.maxSelectedCities)
        )
        currentCityIndex = 0
        pruneWeatherState(toKeep: Set(selectedCities.map(\.code)))
        saveCities()
        fetchAllWeather()
    }

    func fetchAllWeather() {
        cancelAllWeatherWork()
        let cities = selectedCities
        weatherBatchTask = Task { @MainActor [weak self] in
            for (index, city) in cities.enumerated() {
                if index > 0 {
                    do {
                        try await Task.sleep(for: .seconds(Constants.weatherRequestDelay))
                    } catch {
                        return
                    }
                }
                guard let self, isSelected(city) else {
                    continue
                }
                fetchWeather(for: city)
            }
        }
    }

    func fetchWeather(for city: City) {
        guard isSelected(city) else {
            return
        }
        recoveryTasks[city.code]?.cancel()
        recoveryTasks[city.code] = nil
        startWeatherRequest(for: city)
    }

    func getWeather(for city: City) -> WeatherData? {
        weatherDataByCity[city.code]
    }

    func isLoading(for city: City) -> Bool {
        loadingCities.contains(city.code)
    }

    func getError(for city: City) -> String? {
        errorsByCity[city.code]
    }

    nonisolated static func recoveryDelay(forAttempt attempt: Int) -> TimeInterval {
        Constants.weatherRecoveryBaseDelay * pow(2, Double(attempt))
    }

    static func cities(
        forSavedCodes codes: [String]?,
        availableCities: [City]
    ) -> [City] {
        guard let codes else {
            return defaultCities(from: availableCities)
        }
        guard !codes.isEmpty else {
            return []
        }

        let cities = codes.compactMap { code in
            availableCities.first { $0.code == code }
        }
        guard !cities.isEmpty else {
            return defaultCities(from: availableCities)
        }
        return Array(
            TimeZoneManager.sortCitiesByTimezone(cities)
                .prefix(Constants.maxSelectedCities)
        )
    }

    private static func loadTimeFormat(from userDefaults: UserDefaults) -> Bool {
        guard userDefaults.object(forKey: Constants.use24HourTimeKey) != nil else {
            return Constants.defaultUse24Hour
        }
        return userDefaults.bool(forKey: Constants.use24HourTimeKey)
    }

    private static func defaultCities(from availableCities: [City]) -> [City] {
        let cities = Constants.defaultCityCodes.compactMap { code in
            availableCities.first { $0.code == code }
        }
        return TimeZoneManager.sortCitiesByTimezone(cities)
    }

    private func startCityRotationTimer() {
        cityRotationTimer?.invalidate()
        cityRotationTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.cityRotationInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !selectedCities.isEmpty else {
                    return
                }
                currentCityIndex = (currentCityIndex + 1) % selectedCities.count
            }
        }
    }

    private func startLiveTickTimer() {
        guard isPopoverOpen, virtualNow == nil else {
            stopLiveTickTimer()
            return
        }
        liveTickTimer?.invalidate()
        liveTickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.objectWillChange.send()
            }
        }
    }

    private func stopLiveTickTimer() {
        liveTickTimer?.invalidate()
        liveTickTimer = nil
    }

    private func startWeatherTimer() {
        weatherTimer?.invalidate()
        weatherTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.weatherUpdateInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchAllWeather()
            }
        }
    }

    private func saveCities() {
        userDefaults.set(
            selectedCities.map(\.code),
            forKey: Self.selectedCityCodesKey
        )
    }

    private func loadSavedCities() -> [City] {
        guard userDefaults.object(forKey: Self.selectedCityCodesKey) != nil else {
            return Self.cities(
                forSavedCodes: nil,
                availableCities: allAvailableTimezones
            )
        }
        guard let codes = userDefaults.stringArray(forKey: Self.selectedCityCodesKey) else {
            logger.error("Saved city codes have an invalid format; using defaults")
            return Self.cities(
                forSavedCodes: nil,
                availableCities: allAvailableTimezones
            )
        }
        return Self.cities(
            forSavedCodes: codes,
            availableCities: allAvailableTimezones
        )
    }

    private func pruneWeatherState(toKeep codes: Set<String>) {
        weatherDataByCity = weatherDataByCity.filter { codes.contains($0.key) }
        errorsByCity = errorsByCity.filter { codes.contains($0.key) }
        loadingCities = loadingCities.filter { codes.contains($0) }
    }

    private func isSelected(_ city: City) -> Bool {
        selectedCities.contains { $0.code == city.code }
    }

    private func startWeatherRequest(for city: City) {
        weatherTasks[city.code]?.cancel()
        let generation = (requestGenerations[city.code] ?? 0) + 1
        requestGenerations[city.code] = generation
        loadingCities.insert(city.code)
        errorsByCity[city.code] = nil

        let service = weatherService
        let logger = logger
        let primaryQuery = city.displayName
        let fallbackQuery = city.displayName.replacingOccurrences(of: " ", with: "")
        weatherTasks[city.code] = Task { @MainActor [weak self] in
            do {
                let data = try await Self.retrieveWeather(
                    service: service,
                    city: city,
                    primaryQuery: primaryQuery,
                    fallbackQuery: fallbackQuery,
                    logger: logger
                )
                try Task.checkCancellation()
                self?.completeWeatherRequest(
                    for: city,
                    generation: generation,
                    result: .success(data)
                )
            } catch is CancellationError {
                return
            } catch {
                self?.completeWeatherRequest(
                    for: city,
                    generation: generation,
                    result: .failure(error)
                )
            }
        }
    }

    private nonisolated static func retrieveWeather(
        service: any WeatherFetching,
        city: City,
        primaryQuery: String,
        fallbackQuery: String,
        logger: Logger
    ) async throws -> WeatherData {
        do {
            return try await service.fetchWeather(
                cityName: primaryQuery,
                timeZone: city.timeZone
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard fallbackQuery != primaryQuery else {
                throw error
            }
            let message = "Weather fetch failed for \(city.code) using " +
                "\(primaryQuery); trying \(fallbackQuery)"
            logger.warning("\(message, privacy: .public)")
            return try await service.fetchWeather(
                cityName: fallbackQuery,
                timeZone: city.timeZone
            )
        }
    }

    private func completeWeatherRequest(
        for city: City,
        generation: Int,
        result: Result<WeatherData, Error>
    ) {
        guard requestGenerations[city.code] == generation,
              isSelected(city) else {
            return
        }
        weatherTasks[city.code] = nil
        loadingCities.remove(city.code)

        switch result {
        case let .success(data):
            weatherDataByCity[city.code] = data
            errorsByCity[city.code] = nil
            recoveryAttempts[city.code] = nil
        case let .failure(error):
            errorsByCity[city.code] = error.localizedDescription
            let message = "Weather fetch failed for \(city.code): \(error.localizedDescription)"
            logger.error("\(message, privacy: .public)")
            scheduleRecovery(for: city, error: error)
        }
    }

    private func scheduleRecovery(for city: City, error: Error) {
        guard let networkError = error as? NetworkError,
              WeatherService.isRetryable(networkError) else {
            recoveryAttempts[city.code] = nil
            return
        }

        let attempt = recoveryAttempts[city.code] ?? 0
        guard attempt < Constants.maxWeatherRecoveryAttempts else {
            return
        }
        recoveryAttempts[city.code] = attempt + 1
        let delay = Self.recoveryDelay(forAttempt: attempt)
        let message = "Scheduling weather recovery for \(city.code) in \(delay)s; " +
            "attempt \(attempt + 1)/\(Constants.maxWeatherRecoveryAttempts)"
        logger.info("\(message, privacy: .public)")

        recoveryTasks[city.code]?.cancel()
        recoveryTasks[city.code] = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard let self, isSelected(city) else {
                return
            }
            recoveryTasks[city.code] = nil
            fetchWeather(for: city)
        }
    }

    private func cancelAllWeatherWork() {
        weatherBatchTask?.cancel()
        weatherBatchTask = nil

        for code in weatherTasks.keys {
            requestGenerations[code, default: 0] += 1
        }
        weatherTasks.values.forEach { $0.cancel() }
        weatherTasks.removeAll()
        loadingCities.removeAll()

        recoveryTasks.values.forEach { $0.cancel() }
        recoveryTasks.removeAll()
        recoveryAttempts.removeAll()
    }
}
