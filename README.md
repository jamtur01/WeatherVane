# Weathervane

A macOS menu bar app that displays real-time weather and local times for cities around the world.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Menu bar display** — cycles through selected cities showing weather, temperature, and local time
- **Weather details** — temperature, feels-like, humidity, chance of rain, wind, pressure, visibility, and 3-day forecast
- **100+ cities** across all continents and time zones
- **Time offset controls** — shift time forward/backward by hours to plan across time zones
- **Searchable city picker** — select which cities to track
- **Zero dependencies** — uses only Apple frameworks and the free [wttr.in](https://wttr.in) API

## Building

Requires Xcode command-line tools with Swift 5.9+.

```sh
# Development build
swift build

# Universal (arm64 + x86_64) app bundle
./build.sh
open Weathervane.app
```

The build script creates a signed `.app` bundle. Without a Developer ID certificate it falls back to ad-hoc signing — users may need to right-click and select **Open** on first launch.

## Usage

Weathervane lives in the menu bar. Click the status item to open a popover with all selected cities, their current weather, and local times.

- **Hour controls** — shift the displayed time forward or backward
- **Settings** — open the city picker to add or remove cities
- **Quit** — exit from the popover header

Weather data refreshes every 5 minutes. The menu bar rotates through cities every 3 seconds.

## Project Structure

```
Sources/
  main.swift                  App entry point
  AppDelegate.swift           App lifecycle, hides dock icon
  CombinedStatusBarController.swift  Menu bar item and popover management
  CombinedAppState.swift      Central state (cities, weather data, timers)
  CombinedPopoverView.swift   Main popover UI (city rows, forecasts)
  CitySelectionView.swift     Settings window with searchable city list
  WeatherService.swift        wttr.in API client
  WeatherModels.swift         API response Codable structs
  DataModels.swift            App-level data models
  City.swift                  City/timezone model
  TimeZoneData.swift          Static city database (100+ entries)
  TimeZoneManager.swift       Timezone sorting and default city logic
  DateFormatterManager.swift  Shared date formatters
  TimerManager.swift          Timer wrapper utility
  Constants.swift             App-wide constants
  NetworkError.swift          Error types
  SettingsWindowDelegate.swift  Window lifecycle delegate
Info/
  Info.plist                  App bundle configuration
  Weathervane.entitlements    Sandbox entitlements
```

## License

See [LICENSE](LICENSE) for details.
