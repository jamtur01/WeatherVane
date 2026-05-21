import SwiftUI

struct CombinedPopoverView: View {
    @ObservedObject var appState: WeathervaneState
    weak var statusBarController: CombinedStatusBarController?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🌍 Weather & Time")
                    .font(.headline)
                Spacer()
                Button(Constants.quitButtonLabel) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(Constants.defaultPadding)

            Divider()

            // Cities with weather and time
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(appState.selectedCities, id: \.code) { city in
                        CityWeatherRow(
                            city: city,
                            weather: appState.getWeather(for: city),
                            timeString: appState.getTimeString(for: city),
                            isLoading: appState.isLoading(for: city),
                            error: appState.getError(for: city),
                            onRetry: {
                                appState.fetchWeather(for: city)
                            }
                        )
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 12)
            }

            if appState.isVirtualTime {
                Divider()
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.blue)
                    Text("Virtual time active")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Controls
            VStack(spacing: 8) {
                HStack {
                    Button(Constants.resetButtonLabel) { appState.resetTime() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Settings Button
                Button("⚙️ Settings") {
                    statusBarController?.openSettingsWindow()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(Constants.defaultPadding)
        }
        .frame(width: Constants.popoverWidth, height: Constants.popoverHeight)
    }
}

struct CityWeatherRow: View {
    let city: City
    let weather: WeatherData?
    let timeString: String
    let isLoading: Bool
    let error: String?
    let onRetry: () -> Void

    private let weatherService = WeatherService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // City header with time
            HStack {
                Text("\(city.emoji) \(city.code)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                Text(city.displayName)
                    .font(.body)
                Spacer()
                Text(timeString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Weather info
            if isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading weather...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
            } else if let errorMessage = error {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weather unavailable")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Retry") {
                        onRetry()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            } else if let weather = weather {
                WeatherInfoCompact(weather: weather)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct WeatherInfoCompact: View {
    let weather: WeatherData
    private let weatherService = WeatherService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main weather line
            HStack {
                Text(weatherService.getWeatherEmoji(forCondition: weather.weatherDesc))
                    .font(.title2)
                Text(String(format: "%.1f°C", weather.temperature))
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("(feels \(String(format: "%.0f°", weather.feelsLike)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 8) {
                    Label("\(weather.humidity)%", systemImage: "humidity")
                        .font(.caption)
                    Label("\(weather.chanceOfRain)%", systemImage: "cloud.rain")
                        .font(.caption)
                }
            }

            // Weather description
            Text(weather.weatherDesc)
                .font(.caption)
                .foregroundColor(.secondary)

            // Compact forecast
            if !weather.forecasts.isEmpty {
                Divider()
                HStack(spacing: 16) {
                    ForEach(weather.forecasts.prefix(3), id: \.date) { forecast in
                        VStack(spacing: 2) {
                            Text(formatForecastDate(forecast.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            HStack(spacing: 2) {
                                Text(weatherService.getTempEmoji(forTemp: forecast.minTemp))
                                    .font(.caption2)
                                Text(String(format: "%.0f°", forecast.minTemp))
                                    .font(.caption2)
                                Text("-")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(weatherService.getTempEmoji(forTemp: forecast.maxTemp))
                                    .font(.caption2)
                                Text(String(format: "%.0f°", forecast.maxTemp))
                                    .font(.caption2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func formatForecastDate(_ dateString: String) -> String {
        return DateFormatterManager.formatForecastDate(dateString)
    }
}
