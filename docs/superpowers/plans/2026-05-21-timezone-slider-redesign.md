# Timezone Slider Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-row 24-hour day/night time sliders to Weathervane (inspired by TimeZonesMacOS), redesign the popover for larger glanceable time numbers, collapse weather to a one-liner, and adopt an adaptive translucent background.

**Architecture:** Replace the existing `timeSliderOffset: TimeInterval` global hour-offset with a single `virtualNow: Date?` source of truth in `WeathervaneState`. Each row independently computes its own slider handle position from `virtualNow ?? Date()`. The header row and `← Hour / Hour →` controls are removed; new components (`TimezoneRow`, `DayNightBar`, `VisualEffectBackground`) replace the existing `CityWeatherRow` / `WeatherInfoCompact`.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit (NSVisualEffectView, NSStatusItem), SwiftPM. macOS 13+.

**Spec:** `docs/superpowers/specs/2026-05-21-timezone-slider-redesign-design.md`

**Note on testing:** The project has no test target. Verification at each step is `swift build` succeeding and (at integration points) a manual run via `./build.sh && open Weathervane.app` to visually check behavior. Commits happen frequently between green builds.

---

## Task 1: Add VisualEffectBackground wrapper

**Files:**
- Create: `Sources/VisualEffectBackground.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI
import AppKit

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/VisualEffectBackground.swift
git commit -m "Add VisualEffectBackground for popover material"
```

---

## Task 2: Add use24HourTime user setting

**Files:**
- Modify: `Sources/CombinedAppState.swift`
- Modify: `Sources/Constants.swift`

- [ ] **Step 1: Add UserDefaults key to Constants.swift**

Open `Sources/Constants.swift`. Inside the `Constants` enum, add a new constant after `defaultLocaleIdentifier`:

```swift
    // UserDefaults keys
    static let use24HourTimeKey = "use24HourTime"
    static let defaultUse24Hour = true
```

- [ ] **Step 2: Add published property to WeathervaneState**

Open `Sources/CombinedAppState.swift`. Add a new `@Published` property near the top of the class (after `errorsByCity`):

```swift
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
```

- [ ] **Step 3: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Sources/Constants.swift Sources/CombinedAppState.swift
git commit -m "Add use24HourTime user setting"
```

---

## Task 3: Replace timeSliderOffset with virtualNow

**Files:**
- Modify: `Sources/CombinedAppState.swift`

- [ ] **Step 1: Replace the published property**

In `Sources/CombinedAppState.swift`, find this line:

```swift
    @Published var timeSliderOffset: TimeInterval = 0
```

Replace it with:

```swift
    @Published var virtualNow: Date? = nil

    var effectiveNow: Date { virtualNow ?? Date() }
    var isVirtualTime: Bool { virtualNow != nil }
```

- [ ] **Step 2: Replace the time-control methods**

Find this block:

```swift
    func previousHour() {
        timeSliderOffset -= Constants.secondsPerHour
    }

    func nextHour() {
        timeSliderOffset += Constants.secondsPerHour
    }

    func resetTime() {
        timeSliderOffset = 0
    }
```

Replace it with:

```swift
    func setVirtualNow(_ date: Date) {
        virtualNow = date
    }

    func adjustVirtualNow(by seconds: TimeInterval) {
        virtualNow = (virtualNow ?? Date()).addingTimeInterval(seconds)
    }

    func resetTime() {
        virtualNow = nil
    }
```

- [ ] **Step 3: Update getTimeString**

Find:

```swift
    @MainActor
    func getTimeString(for city: City, useSliderTime: Bool = false, shortFormat: Bool = false) -> String {
        let baseDate = useSliderTime ? Date().addingTimeInterval(timeSliderOffset) : Date()
        return shortFormat
            ? DateFormatterManager.formatShortTime(for: city, date: baseDate)
            : DateFormatterManager.formatLongTime(for: city, date: baseDate)
    }
```

Replace with:

```swift
    @MainActor
    func getTimeString(for city: City, shortFormat: Bool = false) -> String {
        let baseDate = effectiveNow
        return shortFormat
            ? DateFormatterManager.formatShortTime(for: city, date: baseDate, use24Hour: use24HourTime)
            : DateFormatterManager.formatLongTime(for: city, date: baseDate, use24Hour: use24HourTime)
    }
```

(The `DateFormatterManager` signature change happens in Task 4 — build will fail until then; that's expected.)

- [ ] **Step 4: Verify build fails as expected**

Run: `swift build 2>&1 | head -30`
Expected: errors about `DateFormatterManager.formatShortTime` / `formatLongTime` missing `use24Hour` parameter. We will fix this in Task 4.

- [ ] **Step 5: Do not commit yet — proceed to Task 4**

---

## Task 4: Extend DateFormatterManager with 24h-aware formatters

**Files:**
- Modify: `Sources/DateFormatterManager.swift`
- Modify: `Sources/Constants.swift`

- [ ] **Step 1: Add format strings to Constants**

In `Sources/Constants.swift`, find:

```swift
    static let shortTimeFormat = "h:mm a"
    static let longTimeFormat = "EEE h:mm a"
```

Replace with:

```swift
    static let shortTimeFormat12 = "h:mm a"
    static let shortTimeFormat24 = "HH:mm"
    static let longTimeFormat12 = "EEE h:mm a"
    static let longTimeFormat24 = "EEE HH:mm"
    static let rowDateFormat = "EEE MMM d"
    static let bigTimeFormat12 = "h:mm a"
    static let bigTimeFormat24 = "HH:mm"
```

- [ ] **Step 2: Update DateFormatterManager**

In `Sources/DateFormatterManager.swift`, replace the entire content with:

```swift
import Foundation

/// Centralized date formatter management.
final class DateFormatterManager {

    private static let lock = NSLock()

    private static let shortFormatter12: DateFormatter = makeFormatter(Constants.shortTimeFormat12)
    private static let shortFormatter24: DateFormatter = makeFormatter(Constants.shortTimeFormat24)
    private static let longFormatter12: DateFormatter = makeFormatter(Constants.longTimeFormat12)
    private static let longFormatter24: DateFormatter = makeFormatter(Constants.longTimeFormat24)
    private static let rowDateFormatter: DateFormatter = makeFormatter(Constants.rowDateFormat)
    private static let bigTimeFormatter12: DateFormatter = makeFormatter(Constants.bigTimeFormat12)
    private static let bigTimeFormatter24: DateFormatter = makeFormatter(Constants.bigTimeFormat24)

    static let forecastDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private init() {}

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Constants.defaultLocaleIdentifier)
        formatter.dateFormat = format
        return formatter
    }

    static func formatShortTime(for city: City, date: Date = Date(), use24Hour: Bool = true) -> String {
        return format(date: date, timeZone: city.timeZone, using: use24Hour ? shortFormatter24 : shortFormatter12)
    }

    static func formatLongTime(for city: City, date: Date = Date(), use24Hour: Bool = true) -> String {
        return format(date: date, timeZone: city.timeZone, using: use24Hour ? longFormatter24 : longFormatter12)
    }

    static func formatBigTime(for city: City, date: Date = Date(), use24Hour: Bool = true) -> String {
        return format(date: date, timeZone: city.timeZone, using: use24Hour ? bigTimeFormatter24 : bigTimeFormatter12)
    }

    static func formatRowDate(for city: City, date: Date = Date()) -> String {
        return format(date: date, timeZone: city.timeZone, using: rowDateFormatter)
    }

    static func formatGMTOffset(for city: City, date: Date = Date()) -> String {
        let offset = city.timeZone.secondsFromGMT(for: date)
        let hours = offset / 3600
        let minutes = abs(offset % 3600) / 60
        if minutes == 0 {
            return "GMT\(hours >= 0 ? "+" : "")\(hours)"
        }
        return String(format: "GMT%+d:%02d", hours, minutes)
    }

    static func formatForecastDate(_ dateString: String) -> String {
        lock.lock()
        let date = forecastDateFormatter.date(from: dateString)
        lock.unlock()

        guard let date = date else { return dateString }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        if calendar.isDate(date, inSameDayAs: today) {
            return "Today"
        } else if calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        lock.lock()
        defer { lock.unlock() }
        return dayOfWeekFormatter.string(from: date)
    }

    private static func format(date: Date, timeZone: TimeZone, using formatter: DateFormatter) -> String {
        lock.lock()
        defer { lock.unlock() }
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 3: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Commit (combines Tasks 3 + 4)**

```bash
git add Sources/CombinedAppState.swift Sources/Constants.swift Sources/DateFormatterManager.swift
git commit -m "Replace timeSliderOffset with virtualNow; add 24h-aware formatters"
```

---

## Task 5: Add 1-second ticking timer

**Files:**
- Modify: `Sources/CombinedAppState.swift`

The popover needs second-by-second redraws (for the blinking colon and live time updates) only when in real-time mode AND the popover is open. The status bar already has its own 1s timer in `CombinedStatusBarController`; this new timer is solely for the popover.

- [ ] **Step 1: Add the timer field and methods**

In `Sources/CombinedAppState.swift`, find the existing timer fields:

```swift
    private var weatherTimer: Timer?
    private var cityRotationTimer: Timer?
```

Add a third field below them:

```swift
    private var liveTickTimer: Timer?
    private var isPopoverOpen = false
```

- [ ] **Step 2: Add control methods**

After the `resetTime()` method, add:

```swift
    func popoverDidOpen() {
        isPopoverOpen = true
        startLiveTickTimer()
    }

    func popoverDidClose() {
        isPopoverOpen = false
        stopLiveTickTimer()
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
```

- [ ] **Step 3: Wire to virtualNow changes**

Replace the existing `virtualNow` property declaration from Task 3:

```swift
    @Published var virtualNow: Date? = nil
```

with:

```swift
    @Published var virtualNow: Date? = nil {
        didSet {
            if virtualNow == nil {
                startLiveTickTimer()
            } else {
                stopLiveTickTimer()
            }
        }
    }
```

- [ ] **Step 4: Update deinit to invalidate the new timer**

Find:

```swift
    deinit {
        weatherTimer?.invalidate()
        cityRotationTimer?.invalidate()
    }
```

Replace with:

```swift
    deinit {
        weatherTimer?.invalidate()
        cityRotationTimer?.invalidate()
        liveTickTimer?.invalidate()
    }
```

- [ ] **Step 5: Hook popover open/close in the status bar controller**

In `Sources/CombinedStatusBarController.swift`, find `showPopover`:

```swift
    private func showPopover(sender: AnyObject?) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.hidePopover(sender: nil)
        }
    }
```

Replace with:

```swift
    private func showPopover(sender: AnyObject?) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
        appState.popoverDidOpen()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.hidePopover(sender: nil)
        }
    }
```

Find `hidePopover`:

```swift
    func hidePopover(sender: AnyObject?) {
        popover.performClose(sender)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
```

Replace with:

```swift
    func hidePopover(sender: AnyObject?) {
        popover.performClose(sender)
        appState.popoverDidClose()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
```

- [ ] **Step 6: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 7: Commit**

```bash
git add Sources/CombinedAppState.swift Sources/CombinedStatusBarController.swift
git commit -m "Add 1s ticking timer for live popover updates"
```

---

## Task 6: Update menu bar status to use new API

The menu bar still calls `getTimeString(for:useSliderTime:shortFormat:)` with the old signature.

**Files:**
- Modify: `Sources/CombinedStatusBarController.swift`

- [ ] **Step 1: Update updateStatusItemTitle**

In `Sources/CombinedStatusBarController.swift`, find:

```swift
        // Add time info
        let timeString = appState.getTimeString(for: currentCity, useSliderTime: false, shortFormat: true)
        titleComponents.append("\(currentCity.emoji) \(currentCity.code) \(timeString)")
```

Replace with:

```swift
        // Add time info
        let timeString = appState.getTimeString(for: currentCity, shortFormat: true)
        titleComponents.append("\(currentCity.emoji) \(currentCity.code) \(timeString)")
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!` (the only callers of the old signature should now be in `CombinedPopoverView.swift`, which we are about to rewrite)

If build fails on `CombinedPopoverView.swift` calls — that's expected. We will fix in later tasks. To proceed cleanly anyway, temporarily comment out the failing lines: leave the popover broken but the status bar working. The popover rewrite (Task 11) replaces them.

- [ ] **Step 3: If popover calls break the build, temporarily fix**

In `Sources/CombinedPopoverView.swift`, find the existing reference to `useSliderTime`:

```swift
                            timeString: appState.getTimeString(for: city, useSliderTime: true),
```

Replace with:

```swift
                            timeString: appState.getTimeString(for: city),
```

And find the `timeSliderOffset` reference:

```swift
            if appState.timeSliderOffset != 0 {
                Divider()
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.blue)
                    Text("Time offset: \(Int(appState.timeSliderOffset / Constants.secondsPerHour))h")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 8)
            }
```

Replace the entire `if` block with:

```swift
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
```

Find the hour-step buttons:

```swift
                // Time Controls
                HStack {
                    Button("← Hour") { appState.previousHour() }
                    Button(Constants.resetButtonLabel) { appState.resetTime() }
                    Button("Hour →") { appState.nextHour() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
```

Replace with (only Reset survives, since `previousHour` and `nextHour` no longer exist):

```swift
                HStack {
                    Button(Constants.resetButtonLabel) { appState.resetTime() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
```

- [ ] **Step 4: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/CombinedStatusBarController.swift Sources/CombinedPopoverView.swift
git commit -m "Adapt callers to new virtualNow API (interim)"
```

---

## Task 7: Update Constants for new popover dimensions

**Files:**
- Modify: `Sources/Constants.swift`

- [ ] **Step 1: Update constants**

In `Sources/Constants.swift`, find:

```swift
    // UI dimensions
    static let popoverWidth: CGFloat = 380
    static let popoverHeight: CGFloat = 550
```

Replace with:

```swift
    // UI dimensions
    static let popoverWidth: CGFloat = 400
    static let popoverHeightMax: CGFloat = 720
    static let popoverHeightMin: CGFloat = 220

    // Row dimensions
    static let rowSpacing: CGFloat = 8
    static let rowCornerRadius: CGFloat = 10
    static let rowHorizontalPadding: CGFloat = 14
    static let rowVerticalPadding: CGFloat = 12

    // Slider (DayNightBar)
    static let dayNightBarHeight: CGFloat = 24
    static let dayNightBarMarkerSize: CGFloat = 24
    static let dayNightBarTickCount: Int = 97
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/Constants.swift
git commit -m "Update Constants for new popover and row dimensions"
```

---

## Task 8: Build the DayNightBar slider component

**Files:**
- Create: `Sources/DayNightBar.swift`

This is the core slider widget. Self-contained: reads `effectiveNow` and a `timeZone`, calls back with new dates on drag.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI
import AppKit

struct DayNightBar: View {
    let timeZone: TimeZone
    let effectiveNow: Date
    var onDrag: (Date) -> Void
    var onReset: () -> Void

    @State private var lastTapTime: Date = .distantPast

    private let totalHeight: CGFloat = Constants.dayNightBarHeight
    private let markerSize: CGFloat = Constants.dayNightBarMarkerSize
    private let tickCount: Int = Constants.dayNightBarTickCount

    var body: some View {
        GeometryReader { geo in
            ZStack {
                tickMarks(width: geo.size.width)
                marker(width: geo.size.width)
            }
            .frame(height: totalHeight)
            .contentShape(Rectangle())
            .gesture(dragGesture(width: geo.size.width))
        }
        .frame(height: totalHeight)
    }

    private func tickMarks(width: CGFloat) -> some View {
        ForEach(0..<tickCount, id: \.self) { tick in
            let hour = Double(tick) / 4.0
            let x = CGFloat(tick) / CGFloat(tickCount - 1) * width
            let isMajor = tick % 24 == 0
            let isHour = tick % 4 == 0
            let height: CGFloat = isMajor ? 14 : (isHour ? 9 : 5)
            let isDaytime = hour >= 6 && hour <= 18
            let color: Color = isDaytime
                ? Color.orange.opacity(0.85)
                : Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
                    let isDark = appearance.bestMatch(from: [.darkAqua]) == .darkAqua
                    return isDark ? NSColor(white: 0.5, alpha: 1) : NSColor(white: 0.3, alpha: 1)
                }))

            Rectangle()
                .fill(color)
                .frame(width: 1, height: height)
                .position(x: x, y: totalHeight / 2)
        }
    }

    private func marker(width: CGFloat) -> some View {
        let x = markerPosition(in: width)
        return ZStack {
            Circle()
                .fill(Color(white: 0.92))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            HStack(spacing: 1) {
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
            }
            .font(.system(size: 7, weight: .bold))
            .foregroundColor(Color(white: 0.35))
        }
        .frame(width: markerSize, height: markerSize)
        .position(x: x, y: totalHeight / 2)
    }

    private func markerPosition(in width: CGFloat) -> CGFloat {
        var cal = Calendar.current
        cal.timeZone = timeZone
        let hour = cal.component(.hour, from: effectiveNow)
        let minute = cal.component(.minute, from: effectiveNow)
        let fraction = (Double(hour) + Double(minute) / 60.0) / 24.0
        return CGFloat(fraction) * width
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let fraction = max(0, min(value.location.x / width, 1.0))
                let targetHour = fraction * 24.0

                var cal = Calendar.current
                cal.timeZone = timeZone
                let dayStart = cal.startOfDay(for: effectiveNow)
                let raw = dayStart.addingTimeInterval(targetHour * 3600)
                // Snap to 1 minute
                let snapped = Date(timeIntervalSince1970: (raw.timeIntervalSince1970 / 60).rounded() * 60)
                onDrag(snapped)
            }
            .onEnded { value in
                let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                if dragDistance < 5 {
                    let now = Date()
                    if now.timeIntervalSince(lastTapTime) < 0.3 {
                        onReset()
                        lastTapTime = .distantPast
                    } else {
                        lastTapTime = now
                    }
                }
            }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/DayNightBar.swift
git commit -m "Add DayNightBar slider component"
```

---

## Task 9: Build the TimezoneRow component (collapsed only)

**Files:**
- Create: `Sources/TimezoneRow.swift`

This task creates the row with everything except the date picker and expanded weather. Those come in Tasks 10 and 11.

- [ ] **Step 1: Create the file**

```swift
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
        Group {
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
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/TimezoneRow.swift
git commit -m "Add TimezoneRow with day/night slider and compact weather"
```

---

## Task 10: Add expanded weather detail to TimezoneRow

**Files:**
- Modify: `Sources/TimezoneRow.swift`

- [ ] **Step 1: Update weatherSection to conditionally show expanded view**

In `Sources/TimezoneRow.swift`, find the `compactWeather` function and the `weatherSection` it's called from. Replace the existing `weatherSection` computed property with:

```swift
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
                                Text(weatherService.getWeatherEmoji(forCondition: forecast.weatherDesc ?? ""))
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
```

- [ ] **Step 2: Verify weather model fields exist**

The plan assumes `WeatherData` has `windSpeed: Int` and that each forecast has a `weatherDesc: String?`. Check the model first.

Run: `grep -nE 'windSpeed|weatherDesc' /Users/james/src/weathervane/Sources/WeatherModels.swift`

If `windSpeed` does not exist on `WeatherData`, replace the `Wind` line in `expandedWeather` with:

```swift
                statPiece("Wind", "\(weather.windSpeed ?? 0) km/h")
```

or, if the property is named differently, adjust accordingly. If forecasts don't have a `weatherDesc`, replace:

```swift
                                Text(weatherService.getWeatherEmoji(forCondition: forecast.weatherDesc ?? ""))
```

with:

```swift
                                Text(weatherService.getTempEmoji(forTemp: forecast.maxTemp))
```

(`getTempEmoji` is already used in the current code; safe fallback.)

- [ ] **Step 3: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Sources/TimezoneRow.swift
git commit -m "Add expandable weather detail to TimezoneRow"
```

---

## Task 11: Add date picker to TimezoneRow

**Files:**
- Modify: `Sources/TimezoneRow.swift`

- [ ] **Step 1: Add state and binding for the popover**

In `Sources/TimezoneRow.swift`, add to the `@State` properties (just below `@State private var weatherExpanded = false`):

```swift
    @State private var datePickerOpen = false
    @State private var pendingDate = Date()
```

- [ ] **Step 2: Make the date label trigger the picker**

In `headerRow`, replace the existing date `Text(...)` block:

```swift
                    Text(DateFormatterManager.formatRowDate(for: city, date: effectiveNow))
                        .font(.system(size: 12))
                        .foregroundColor(dateColor)
                        .underline(color: dateColor.opacity(0.5))
```

with:

```swift
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
```

- [ ] **Step 3: Add the date picker content view**

Add this computed property at the end of the `TimezoneRow` struct (just before the closing brace):

```swift
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
            .onChange(of: pendingDate) { _, newDate in
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
```

- [ ] **Step 4: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/TimezoneRow.swift
git commit -m "Add date picker to TimezoneRow date label"
```

---

## Task 12: Rewrite CombinedPopoverView with new layout

**Files:**
- Modify: `Sources/CombinedPopoverView.swift`

- [ ] **Step 1: Replace the entire file**

Open `Sources/CombinedPopoverView.swift` and replace the entire content with:

```swift
import SwiftUI

struct CombinedPopoverView: View {
    @ObservedObject var appState: WeathervaneState
    weak var statusBarController: CombinedStatusBarController?

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                content
                footer
            }
        }
        .frame(width: Constants.popoverWidth)
        .frame(minHeight: Constants.popoverHeightMin, maxHeight: Constants.popoverHeightMax)
    }

    @ViewBuilder
    private var content: some View {
        if appState.selectedCities.isEmpty {
            emptyState
        } else {
            cityList
        }
    }

    private var cityList: some View {
        ScrollView {
            VStack(spacing: Constants.rowSpacing) {
                ForEach(appState.selectedCities, id: \.code) { city in
                    TimezoneRow(
                        city: city,
                        weather: appState.getWeather(for: city),
                        isLoading: appState.isLoading(for: city),
                        error: appState.getError(for: city),
                        effectiveNow: appState.effectiveNow,
                        use24Hour: appState.use24HourTime,
                        isFrozen: appState.isVirtualTime,
                        onRetry: { appState.fetchWeather(for: city) },
                        onDrag: { newDate in
                            withAnimation(.easeOut(duration: 0.05)) {
                                appState.setVirtualNow(newDate)
                            }
                        },
                        onReset: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                appState.resetTime()
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No cities yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Add some to start tracking time and weather.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                statusBarController?.openSettingsWindow()
            } label: {
                Label("Add City", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Divider().opacity(0.5)

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    appState.resetTime()
                }
            } label: {
                Text("Reset")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(!appState.isVirtualTime)
            .padding(.horizontal, 12)

            HStack {
                footerButton(systemImage: "plus", label: "Add") {
                    statusBarController?.openSettingsWindow()
                }
                Spacer()
                footerButton(systemImage: "gearshape", label: "Settings") {
                    statusBarController?.openSettingsWindow()
                }
                Spacer()
                footerButton(systemImage: "power", label: "Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 10)
        }
    }

    private func footerButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Manual visual check**

Run: `./build.sh && open Weathervane.app`

Expected:
- Menu bar still shows rotating cities with time/weather
- Clicking menu bar opens the redesigned popover with city rows
- Each row shows: city name, GMT offset, date, big time, slider with day/night tick marks, weather one-liner
- Slider handle is roughly at the row's current local hour
- Dragging any row's handle moves all other handles to the same moment in their zones
- Double-tapping a handle resets
- Reset button at footer enables only when time is frozen
- Add / Settings / Quit buttons appear at the very bottom

If anything looks wrong, fix before committing.

- [ ] **Step 4: Commit**

```bash
git add Sources/CombinedPopoverView.swift
git commit -m "Redesign popover with TimezoneRow, footer, and translucent background"
```

---

## Task 13: Add 24-hour toggle to CitySelectionView (Settings)

**Files:**
- Modify: `Sources/CitySelectionView.swift`

- [ ] **Step 1: Add the toggle in the header**

Open `Sources/CitySelectionView.swift`. Find the header `VStack`:

```swift
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Cities")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Choose cities to display in your timezone list:")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
```

Replace with:

```swift
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Select Cities")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Choose cities to display in your timezone list:")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("24-hour time", isOn: $appState.use24HourTime)
                        .toggleStyle(.switch)
                }
            }
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/CitySelectionView.swift
git commit -m "Add 24-hour time toggle to Settings"
```

---

## Task 14: Final QA pass and polish

**Files:** none modified by default; this is a verification task.

- [ ] **Step 1: Full rebuild**

```bash
swift build && ./build.sh
```

Expected: both succeed.

- [ ] **Step 2: Open the app and walk the checklist**

Run: `open Weathervane.app`

For each item, verify or note what's wrong:

- [ ] Menu bar: cycles every 3s, shows current city's weather + time
- [ ] Popover background: translucent, adapts to system light/dark mode
- [ ] City row: name, GMT, date, big monospaced time, all readable
- [ ] Colon blinks once per second in real-time mode
- [ ] Slider tick marks: orange for 6am–6pm hours, gray for night
- [ ] Slider handle: rounded white circle with `<>` icon, positioned at row's local hour
- [ ] Drag any slider: all handles move in lockstep; popover times update live
- [ ] Reset button (footer): disabled by default; enables when time is frozen; resets all rows
- [ ] Double-tap handle: also resets
- [ ] Tap date label: opens date picker; selecting jumps to that date keeping current time-of-day
- [ ] "Today" button in date picker: resets time and closes picker
- [ ] Weather one-liner under slider: emoji, temp, condition
- [ ] Tap weather line: expands to show feels/humidity/rain/wind + 3-day forecast
- [ ] Tap again: collapses
- [ ] Remove all cities via Settings: popover shows empty state with "Add City" button
- [ ] 24-hour toggle in Settings: switches all time displays between 12h / 24h
- [ ] Quit button in popover: terminates the app

- [ ] **Step 3: Fix any issues found**

For each problem, edit the relevant file, rebuild, re-verify. Commit fixes separately.

- [ ] **Step 4: Final commit if anything was changed during QA**

```bash
git add -A
git commit -m "QA fixes for timezone slider redesign"
```

---

## Self-Review Notes

- All spec sections covered: data model (Task 3), formatters (Task 4), ticking (Task 5), constants/sizing (Task 7), slider (Task 8), row (Tasks 9–11), popover layout + footer + background + empty state (Task 12), Settings toggle (Task 13), QA (Task 14).
- No placeholders. All code shown inline.
- Type signatures consistent: `effectiveNow`, `setVirtualNow`, `resetTime`, `isVirtualTime` used identically across tasks.
- Task 6 includes a fallback for the case where editing one file breaks another mid-refactor; the temporary fix is reverted by Task 12's full rewrite.
