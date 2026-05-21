import SwiftUI

struct TimezoneRow: View {
    let city: City
    let weather: WeatherData?
    let isLoading: Bool
    let error: String?
    let effectiveNow: Date
    let use24Hour: Bool
    let isFrozen: Bool
    let onRetry: () -> Void
    let onDrag: (Date) -> Void
    let onReset: () -> Void

    @State private var colonVisible = true
    @State private var weatherExpanded = false
    @State private var datePickerOpen = false
    @State private var pendingDate = Date()

    private let weatherService = WeatherService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            DayNightBar(
                timeZone: city.timeZone,
                effectiveNow: effectiveNow,
                onDrag: onDrag,
                onReset: onReset
            )
            weatherSection
        }
        .padding(.horizontal, Constants.rowHorizontalPadding)
        .padding(.vertical, Constants.rowVerticalPadding)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(Constants.rowCornerRadius)
        .onAppear { colonVisible = false }
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(city.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                HStack(spacing: 8) {
                    Text(DateFormatterManager.formatGMTOffset(for: city, date: effectiveNow))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(DateFormatterManager.formatRowDate(for: city, date: effectiveNow))
                        .font(.system(size: 12))
                        .foregroundColor(dateColor)
                        .underline(color: dateColor.opacity(0.5))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            pendingDate = effectiveNow
                            datePickerOpen = true
                        }
                        .popover(isPresented: $datePickerOpen, arrowEdge: .bottom) {
                            datePickerContent
                        }
                }
            }
            Spacer()
            bigTimeView
        }
    }

    private var bigTimeView: some View {
        let timeString = DateFormatterManager.formatBigTime(for: city, date: effectiveNow, use24Hour: use24Hour)
        let parts = timeString.split(separator: ":", maxSplits: 1).map(String.init)
        let hour = parts.first ?? timeString
        let minute = parts.count > 1 ? parts[1] : ""

        return HStack(spacing: 0) {
            Text(hour)
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .monospacedDigit()
            Text(":")
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .monospacedDigit()
                .opacity(isFrozen ? 1 : (colonVisible ? 1 : 0.15))
                .animation(isFrozen ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: colonVisible)
                .offset(y: -1.5)
            Text(minute)
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .foregroundColor(timeColor)
    }

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading weather…")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } else if let errorMessage = error {
                HStack(spacing: 6) {
                    Text("⚠️ Weather unavailable")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { onRetry() }
            } else if let weather = weather {
                compactWeather(weather)
                if weatherExpanded {
                    expandedWeather(weather)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func compactWeather(_ weather: WeatherData) -> some View {
        HStack(spacing: 6) {
            Text(weatherService.getWeatherEmoji(forCondition: weather.weatherDesc))
                .font(.system(size: 13))
            Text(String(format: "%.0f°", weather.temperature))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Text(weather.weatherDesc)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Image(systemName: weatherExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                weatherExpanded.toggle()
            }
        }
    }

    private func expandedWeather(_ weather: WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                statPiece("Feels", String(format: "%.0f°", weather.feelsLike))
                statSeparator
                statPiece("Humidity", "\(weather.humidity)%")
                statSeparator
                statPiece("Rain", "\(weather.chanceOfRain)%")
                statSeparator
                statPiece("Wind", "\(weather.windSpeed) km/h")
                Spacer()
            }
            if !weather.forecasts.isEmpty {
                Divider().opacity(0.5)
                HStack(spacing: 12) {
                    ForEach(weather.forecasts.prefix(3), id: \.date) { forecast in
                        VStack(spacing: 2) {
                            Text(DateFormatterManager.formatForecastDate(forecast.date))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            HStack(spacing: 3) {
                                Text(weatherService.getWeatherEmoji(forCondition: forecast.description))
                                    .font(.system(size: 12))
                                Text(String(format: "%.0f–%.0f°", forecast.minTemp, forecast.maxTemp))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func statPiece(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    private var statSeparator: some View {
        Text(" · ")
            .font(.system(size: 10))
            .foregroundColor(.secondary.opacity(0.5))
    }

    private var datePickerContent: some View {
        VStack(spacing: 12) {
            DatePicker(
                "",
                selection: $pendingDate,
                in: dateRange,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .environment(\.timeZone, city.timeZone)
            .onChange(of: pendingDate) { newDate in
                applyPickedDate(newDate)
            }

            HStack {
                Button("Today") {
                    onReset()
                    datePickerOpen = false
                }
                Spacer()
                Button("Done") {
                    datePickerOpen = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .frame(width: 320)
    }

    private var dateRange: ClosedRange<Date> {
        let now = Date()
        let oneYearAgo = now.addingTimeInterval(-365 * 86400)
        let fiveYearsAhead = now.addingTimeInterval(5 * 365 * 86400)
        return oneYearAgo...fiveYearsAhead
    }

    private func applyPickedDate(_ pickedDate: Date) {
        var cal = Calendar.current
        cal.timeZone = city.timeZone

        let picked = cal.dateComponents([.year, .month, .day], from: pickedDate)
        let current = cal.dateComponents([.hour, .minute, .second], from: effectiveNow)

        var combined = DateComponents()
        combined.year = picked.year
        combined.month = picked.month
        combined.day = picked.day
        combined.hour = current.hour
        combined.minute = current.minute
        combined.second = current.second
        combined.timeZone = city.timeZone

        if let result = cal.date(from: combined) {
            onDrag(result)
        }
    }

    // MARK: - Day-shift coloring

    private var dayOffset: Int {
        var localCal = Calendar.current
        localCal.timeZone = TimeZone.current
        var remoteCal = Calendar.current
        remoteCal.timeZone = city.timeZone

        let localComps = localCal.dateComponents([.year, .month, .day], from: effectiveNow)
        let remoteComps = remoteCal.dateComponents([.year, .month, .day], from: effectiveNow)

        guard let localDate = localCal.date(from: localComps),
              let remoteDate = localCal.date(from: remoteComps) else {
            return 0
        }
        return localCal.dateComponents([.day], from: localDate, to: remoteDate).day ?? 0
    }

    private var dateColor: Color {
        switch dayOffset {
        case ..<0: return Color(red: 0.78, green: 0.0, blue: 0.0)
        case 1...: return Color(red: 0.0, green: 0.47, blue: 0.0)
        default: return .secondary
        }
    }

    private var timeColor: Color {
        switch dayOffset {
        case ..<0: return Color(red: 0.78, green: 0.0, blue: 0.0)
        case 1...: return Color(red: 0.0, green: 0.47, blue: 0.0)
        default: return .primary
        }
    }
}
