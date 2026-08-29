# Weathervane

A native macOS menu bar app for comparing local times and weather across cities.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)

## Features

- Menu bar display that rotates through selected cities
- Current temperature, feels-like temperature, humidity, rain chance, wind, and a three-day forecast
- More than 100 cities across global time zones
- Draggable full-day time scale and date picker for planning across time zones
- Searchable city picker for selecting up to 50 cities
- 12-hour and 24-hour clock formats
- No third-party runtime dependencies; weather comes from the free [wttr.in](https://wttr.in) API

## Requirements

- macOS 13 or later
- Swift 6 and the Xcode command-line tools for local builds

## Building

```sh
# Development build
swift build

# Universal arm64 and x86_64 application bundle
./build.sh
open Weathervane.app
```

The build script creates a hardened-runtime app bundle. Local builds use an ad-hoc signature unless both
`APPLE_DEVELOPER_CERTIFICATE_P12_BASE64` and `APPLE_DEVELOPER_CERTIFICATE_PASSWORD` are set.

## Usage

Click the menu bar item to open the city list. Drag a city's time scale to compare another time, or click its date to
choose a day. Double-click the scale or select Reset to return to the current time.

Open Settings to search for cities, change the clock format, or clear the selection. Weather refreshes every five
minutes, and the menu bar rotates through selected cities every three seconds.

## Quality checks

```sh
swiftformat Sources Tests Icon --lint --cache ignore
swiftlint lint --strict --no-cache Sources Tests Icon
shellcheck build.sh
shellcheck Scripts/check-coverage.sh
shfmt -d -i 2 build.sh Scripts/check-coverage.sh
Scripts/check-coverage.sh
swift build -c release -Xswiftc -warnings-as-errors
```

GitHub Actions runs these checks for pushes and pull requests. Version tags matching `v*` also build, sign, notarize,
staple, and publish the app archive.

## Project structure

```text
Sources/
  main.swift                         App entry point
  AppDelegate.swift                  Application lifecycle
  CombinedStatusBarController.swift Menu bar, popover, and settings windows
  CombinedAppState.swift             City selection, clocks, and weather state
  CombinedPopoverView.swift          Main popover UI
  CitySelectionView.swift            Searchable settings UI
  TimezoneRow.swift                  City clock, planner, and weather UI
  DayNightBar.swift                  Full-day time scale
  WeatherService.swift               Async wttr.in client and retry policy
  WeatherModels.swift                API response models
  DataModels.swift                   App weather models
  City.swift                         City and time-zone model
  TimeZoneData.swift                 Static city database
  CityCatalog.swift                  City sorting and defaults
  DateFormatting.swift               Thread-safe city-local formatting
  Constants.swift                    Shared constants
  NetworkError.swift                 Weather request errors
Info/
  Info.plist                         Application bundle metadata
Tests/WeathervaneTests/              Behavior and regression tests
```
