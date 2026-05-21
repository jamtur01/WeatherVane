import Foundation
import CoreGraphics

enum Constants {
    // Timer intervals
    static let cityRotationInterval: TimeInterval = 3.0
    static let weatherUpdateInterval: TimeInterval = 300.0 // 5 minutes
    static let weatherRequestDelay: TimeInterval = 1.0 // Delay between API requests to avoid rate limiting

    // Time calculations
    static let secondsPerHour: TimeInterval = 3600

    // UI dimensions
    static let popoverWidth: CGFloat = 380
    static let popoverHeight: CGFloat = 550
    static let settingsWindowWidth: CGFloat = 500
    static let settingsWindowHeight: CGFloat = 600

    // UI layout
    static let defaultPadding: CGFloat = 16

    // Default values
    static let defaultCityCodes = ["NYC", "LHR", "MEL", "LAX", "CHI"]
    static let defaultMenuBarTitle = "⏳ Loading..."

    // Performance
    static let maxCitiesToDisplay = 50

    // Date formatting
    static let shortTimeFormat = "h:mm a"
    static let longTimeFormat = "EEE h:mm a"
    static let defaultLocaleIdentifier = "en_US"

    // UserDefaults keys
    static let use24HourTimeKey = "use24HourTime"
    static let defaultUse24Hour = true

    // Button labels
    static let quitButtonLabel = "Quit"
    static let cancelButtonLabel = "Cancel"
    static let saveButtonLabel = "Save"
    static let resetButtonLabel = "Reset"
}
