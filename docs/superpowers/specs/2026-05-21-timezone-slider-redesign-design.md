# Timezone Slider Redesign

**Date:** 2026-05-21
**Status:** Approved
**Related app:** [m-tse/TimeZonesMacOS](https://github.com/m-tse/TimeZonesMacOS) (visual + interaction reference)

## Summary

Redesign the Weathervane popover around per-row time sliders inspired by TimeZonesMacOS. Each city row gets a 24-hour day/night ruler with a draggable handle; dragging any row shifts a single shared "virtual time" that all rows reflect in their own zones. Weather stays but collapses to a single compact line with an expand-on-tap detail panel. The overall layout grows larger numbers, drops clutter (airport codes, hour-step buttons, header row), and adopts an adaptive translucent background.

## Goals

- Add per-row time-zone sliders with day/night visualization, matching the look and interaction of TimeZonesMacOS.
- Make the popover larger, cleaner, easier to read at a glance.
- Preserve weather data, but de-emphasize it (compact one-liner, expand on demand).
- Keep all existing capabilities: rotating menu bar, persisted city list, 3-day forecast access, settings/city picker.

## Non-goals

- Pivoting away from weather. Weather stays as a first-class feature, just visually subordinated.
- Adjusting historical or forecast weather to match the slider's virtual time — weather is always "now."
- Persisting virtual time across launches. App always reopens in real-time mode.
- Drag-to-reorder cities. Order remains west → east by GMT offset (existing behavior).

## Approach

Replace `timeSliderOffset: TimeInterval` with `virtualNow: Date?` in `WeathervaneState`. `nil` means "follow the real clock" (default); a non-nil value freezes the entire UI at that moment. All time displays read from `virtualNow ?? Date()`. The slider and date picker both write to this single field.

This avoids the two-field tangle of separate "hour offset" and "day offset" data, and makes the slider math trivial — each row independently maps `virtualNow` to its own local hour-of-day for handle positioning.

## Architecture

### Files modified

| File | Change |
|------|--------|
| `Sources/CombinedAppState.swift` | Replace `timeSliderOffset` with `virtualNow: Date?`. Add `setVirtualNow(_:)`, `adjustVirtualNow(by:)`, `resetTime()`. Add 1s ticking timer (active when `virtualNow == nil` and popover open). |
| `Sources/CombinedPopoverView.swift` | Rewrite popover layout. Remove header row, remove `← Hour / Hour →` buttons. Replace `CityWeatherRow` body with new `TimezoneRow` (in new file). Add new footer (full-width Reset + 3-up Add/Settings/Quit). |
| `Sources/Constants.swift` | Add tick-ruler constants (97 ticks, 24h range, 1-min snap). Update popover dimensions (width 400, auto height capped 720). Drop `← Hour`, `Hour →` labels and `defaultPadding` if newly unused. |
| `Sources/CombinedStatusBarController.swift` | Verify popover content-size auto-sizes correctly with new layout; no logic changes expected. |
| `Sources/DateFormatterManager.swift` | Add formatter for `EEE MMM d` (date label) and `HH`/`mm` 24h components if not present. |

### Files added

| File | Purpose |
|------|---------|
| `Sources/TimezoneRow.swift` | New per-city row view: city header, big time, day/night ruler, weather one-liner with expand. Includes the expanded weather detail subview. |
| `Sources/DayNightBar.swift` | Custom slider view. SwiftUI `GeometryReader` + tick marks + draggable handle, with day/night coloring. |
| `Sources/VisualEffectBackground.swift` | `NSViewRepresentable` wrapping `NSVisualEffectView` with `.popover` material, `.behindWindow` blending, vibrancy on. Applied as popover background. |

### Files unchanged

`AppDelegate.swift`, `main.swift`, `WeatherService.swift`, `WeatherModels.swift`, `City.swift`, `TimeZoneData.swift`, `TimeZoneManager.swift`, `TimerManager.swift`, `NetworkError.swift`, `CitySelectionView.swift`, `SettingsWindowDelegate.swift`, `DataModels.swift`.

## Data model

```swift
// CombinedAppState.swift — WeathervaneState
@Published var virtualNow: Date? = nil

var effectiveNow: Date { virtualNow ?? Date() }
var isVirtualTime: Bool { virtualNow != nil }

func setVirtualNow(_ date: Date) { virtualNow = date }
func adjustVirtualNow(by seconds: TimeInterval) {
    virtualNow = (virtualNow ?? Date()).addingTimeInterval(seconds)
}
func resetTime() { virtualNow = nil }
```

- **Removed:** `timeSliderOffset: TimeInterval`, `previousHour()`, `nextHour()`.
- **Kept:** `selectedCities`, `currentCityIndex`, `weatherDataByCity`, `loadingCities`, `errorsByCity`, all weather methods, city persistence.
- **Replaced caller:** `getTimeString(for:useSliderTime:shortFormat:)` simplifies — there's no longer an optional "with offset" mode; it always uses `effectiveNow`.

### Ticking

A new `Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true)` fires every second to redraw live time displays. It is started when:
- the popover opens *and* `virtualNow == nil`

It is stopped when:
- the popover closes, or
- `virtualNow` is set (frozen time doesn't need ticks)

When `virtualNow` is cleared by `resetTime()`, the timer restarts if the popover is open.

Existing 3-second city rotation timer (for the menu bar) and 5-minute weather timer continue unchanged.

### Persistence

- `selectedCityCodes` UserDefaults key remains unchanged.
- `virtualNow` is NOT persisted across launches.
- A new UserDefaults key `use24HourTime` (Bool, default true) controls time format. Set in Settings.
- The deleted `timeSliderOffset` field had no UserDefaults persistence, so no migration is needed.

## TimezoneRow component

### Layout

```
┌───────────────────────────────────────────────────┐
│  New York                            05:38        │  city + big time
│  GMT-4   Thu Apr 16                               │  GMT + tappable date
│                                                   │
│   ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⟨◯⟩⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯                  │  day/night slider
│                                                   │
│  ☀️  18°  Partly cloudy                       ⌄   │  weather one-liner
└───────────────────────────────────────────────────┘
```

### Header (top row)

- **Left:** city `displayName` (no airport code, no emoji prefix). 15pt semibold (or 18pt — see typography below). Primary color.
- **Right:** time display (next section).
- **Sub-row under city name:**
  - `GMT-4` (or `GMT+5:30` for half-hour zones), 12pt secondary color.
  - 8pt gap.
  - Date label, formatted `EEE MMM d` (e.g., `Thu Apr 16`), 12pt, **underlined**, tappable → opens date picker.
  - Day-shift coloring: if the date in this row's zone differs from the date in the user's local zone (computed for `effectiveNow`), the date label is red (past day) or green (future day). Otherwise secondary color.

### Big time display

- Format: `HH:mm` (24h) or `h:mm a` (12h) per `use24HourTime` setting.
- Font: 30pt, weight medium, rounded design, monospaced digits. Primary color.
- The `:` colon blinks once per second (1s ease-in-out, repeats forever) when `virtualNow == nil`. When virtual time is frozen, the colon is fully opaque (no blink).
- Day-shift coloring: same red/green treatment as the date label when row's zone is on a different day than local.

### Day/night slider — see DayNightBar section below.

### Weather one-liner

- Layout: emoji · `18°` · `condition text` (truncates if needed) · spacer · chevron `⌄`
- Font: 11pt secondary color
- Whole line is tappable → toggles expanded state
- Loading: `ProgressView(controlSize: .small)` replaces emoji
- Error: orange `⚠️ Weather unavailable` text, tap to retry (calls `appState.fetchWeather(for:)`)

### Expanded weather (state lives in row's `@State`)

```
  Feels 17°  ·  Humidity 64%  ·  Rain 20%  ·  Wind 12 km/h
  ────────────────────────────────────────────────────────
  Tue          Wed          Thu
  🌤 12–19°   ☀️ 14–22°   🌧 11–18°
```

- Stats row: 10pt secondary, inline, `·` separators
- Forecast strip: 3 days from `weather.forecasts.prefix(3)`, each: day-abbrev (`EEE`) + emoji + min–max range
- Animation: 200ms ease-in-out on expand/collapse height change
- Dropped from current implementation: pressure, visibility (low signal, adds clutter)

### Row container

- Internal padding: 14pt horizontal, 12pt vertical
- Background: `Color.primary.opacity(0.04)` with 10pt corner radius
- Inter-row spacing: 8pt vertical gap
- Collapsed height: ~120pt. Expanded: ~200pt.

## DayNightBar component

A custom SwiftUI view that draws a 24-hour ruler with day/night-colored tick marks and a draggable handle. Closely mirrors `DayNightBar` in TimeZonesMacOS.

### Inputs

```swift
let timeZone: TimeZone        // this row's zone
let effectiveNow: Date        // virtualNow ?? Date(), from app state
var onDrag: (Date) -> Void    // callback: user dragged to this new effective moment
var onReset: () -> Void       // callback: user double-tapped to reset
```

The view does NOT own state — it reads from `effectiveNow` and writes back via callbacks. This keeps the single source of truth in `WeathervaneState`.

### Geometry

- Total height: 24pt
- Width: row width minus padding (~370pt expected)
- 97 ticks total, indices 0...96, each representing a 15-min increment from 00:00 to 24:00
- Tick x-position: `(i / 96) * width`
- Three tick heights:
  - **Major** (every 6 hours, i ∈ {0, 24, 48, 72, 96}): 14pt
  - **Hour** (every 4 ticks, i % 4 == 0): 9pt
  - **15-min** (all others): 5pt
- Tick width: 1pt

### Tick color (day/night)

For each tick, compute its hour-of-day: `hour = i / 4.0`. If `6 ≤ hour ≤ 18`, the tick is **orange** (matches reference). Otherwise it's a darker neutral gray (resolved adaptively for light/dark mode — light gray on light, dark gray on dark).

### Handle (marker)

- 24pt diameter circle, fill `Color(white: 0.92)`, drop shadow `radius: 2, y: 1, opacity: 0.3`
- Contents: two SF Symbols `chevron.left` + `chevron.right`, 7pt bold, color `Color(white: 0.35)`
- x-position computed from `effectiveNow` in this row's zone:
  ```
  let hour = cal.component(.hour, from: effectiveNow)    // in row's TZ
  let minute = cal.component(.minute, from: effectiveNow)
  let fraction = (Double(hour) + Double(minute)/60) / 24
  let x = fraction * width
  ```
- All rows compute this independently — when `virtualNow` changes, every row's handle moves to its new local-hour position.

### Drag interaction

`DragGesture(minimumDistance: 0)` on the bar's content area:
- `onChanged`: compute `fraction = clamp(value.location.x / width, 0, 1)`, then `targetHour = fraction * 24`. Build target date from `cal.startOfDay(for: effectiveNow) + targetHour * 3600` in row's zone. Snap to 1 minute: `target = round(target * 60) / 60`. Call `onDrag(target)`.
- `onEnded`: if drag distance < 5pt, treat as a tap. Detect double-tap (within 300ms) → call `onReset()`.

The drag mapping always uses the **selected day** (the day component of `effectiveNow` in this row's zone) so dragging never accidentally changes the day. To change days, use the date picker.

### Animations

- Drag updates: no animation (1:1 follow finger).
- Reset (via double-tap or footer button): handles glide to new positions over 200ms ease-out.
- Date picker jump: same 200ms glide.

## Date picker

- Tapping a row's underlined date opens a SwiftUI `.popover` anchored to that label.
- Content: `DatePicker("", selection: $tempDate, in: dateRange, displayedComponents: .date).datePickerStyle(.graphical)`, plus a "Today" button at the bottom that calls `resetTime()` and dismisses.
- Range: `Date().addingTimeInterval(-86400 * 365)` to `Date().addingTimeInterval(86400 * 365 * 5)`.
- Selecting a new date: builds a new `Date` by combining the picked calendar date (in the row's zone) with the **current time-of-day** of `effectiveNow` in that same zone. Calls `setVirtualNow(newDate)`.
- Closing the popover (click outside) commits the selection.

## Footer

```
┌───────────────────────────────────────────────────┐
│  ┌─────────────────────────────────────────────┐  │
│  │                   Reset                     │  │
│  └─────────────────────────────────────────────┘  │
│                                                   │
│    + Add        ⚙ Settings        ⏻ Quit          │
└───────────────────────────────────────────────────┘
```

- **Reset** — full-width capsule. Enabled only when `isVirtualTime`. Calls `resetTime()`. Animates handles back over 200ms.
- **+ Add** — opens the existing `CitySelectionView` window (the city picker).
- **⚙ Settings** — opens the same `CitySelectionView` window. The window gains a small preferences strip at the top (or footer) holding the `use24HourTime` toggle. Both buttons open the same window; the difference is convention, not behavior. A more developed Settings sheet is deferred.
- **⏻ Quit** — `NSApplication.shared.terminate(nil)`.
- All three buttons in the lower row use SF Symbols (+/gear/power) with a small label, no border, 13pt icon + 10pt label, evenly spaced.

## Background

`NSVisualEffectView` via an `NSViewRepresentable` wrapper:

```swift
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}
```

Applied as `.background(VisualEffectBackground())` on the popover root. Adapts to light/dark mode automatically.

## Sizing

- **Width:** 400pt (constant).
- **Height:** auto — computed from sum of row heights (collapsed/expanded) + footer + padding.
- **Max height:** 720pt. Content scrolls if taller. (`ScrollView` wraps the city list; footer stays pinned.)
- **Min height:** ~200pt (footer + empty-state message).

## Empty state

When `selectedCities.isEmpty`:
- Show a centered message: `"No cities yet. Add some to start tracking time and weather."`
- A single `+ Add City` button below the message → opens the city picker.
- Footer Reset is hidden in this state.

## DST and 12h/24h

- **DST:** all GMT-offset labels use `timeZone.secondsFromGMT(for: effectiveNow)`, which is date-aware. The displayed `GMT-4` shifts to `GMT-5` automatically across DST boundaries.
- **12h/24h:** new UserDefaults key `use24HourTime` (default `true`). Toggle lives in the Settings sheet. All time displays in the popover and the menu bar respect this setting.

## Menu bar (unchanged)

The 3-second city rotation in the status bar continues. The status bar displays the current rotation city's local time + weather using `effectiveNow`, so when the user drags a slider, the menu bar also reflects virtual time. Format respects `use24HourTime`.

## Edge cases

- **Removing the current rotation city:** `currentCityIndex` clamps to `min(currentCityIndex, selectedCities.count - 1)`.
- **All cities removed:** popover shows empty state; menu bar shows the default `⏳ Loading...` placeholder.
- **Drag handle past ruler edge:** clamps to 0 or 96 (i.e., 00:00 or 23:59 in row's zone). To go further, user uses the date picker.
- **DST jump during drag:** the drag mapping uses `cal.startOfDay(for: effectiveNow)` and adds hours. On the DST transition day, this gives the wall-clock hour the user expects; the resulting absolute `Date` may be ±1h offset but the displayed time matches the dragged position.
- **Weather error on a row:** weather line shows the error state; the row's time/slider continue to work normally.

## Migration

- `timeSliderOffset` and the `← Hour` / `Hour →` buttons are deleted outright per the "replace, don't deprecate" rule. No compatibility shims, no migration code.
- Existing UserDefaults (`selectedCityCodes`) untouched.
- First launch after upgrade: app starts in real-time mode (default `virtualNow == nil`).

## Testing

- **Manual:** verify all interactions in the running app — drag slider on each row, date picker, reset, weather expand, light/dark mode, DST boundary (test by changing system clock).
- **Unit (if any added):** consider tests for `effectiveNow` semantics in `WeathervaneState`, day-shift detection in `TimezoneRow`, and the drag-to-Date mapping in `DayNightBar`. Existing project has no test target; adding one is optional and out of scope for this design.

## Open questions

None remaining — all design questions answered during brainstorming.

## Out of scope

- A separate Settings tab beyond the existing city picker. The `use24HourTime` toggle is added; deeper preferences UI is deferred.
- Drag-to-reorder cities.
- Per-city background colors (the reference supports this; not needed for v1).
- Showing weather for the virtual time. Weather always reflects the real "now."
- Persisting `virtualNow` across launches.
- Highlighting a "home" / "reference" timezone with a tint (reference app supports this).
