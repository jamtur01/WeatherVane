import SwiftUI
import AppKit

final class CombinedStatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let appState = CombinedAppState()
    private var updateTimer: Timer?
    weak var settingsWindow: NSWindow?
    internal var settingsWindowDelegate: NSWindowDelegate?

    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()

        setupPopover()
        setupStatusItem()
    }

    func setup() {
        Task { @MainActor [weak self] in
            self?.updateStatusItemTitle()
        }
        startUpdateTimer()
    }

    deinit {
        updateTimer?.invalidate()
    }

    func cleanup() {
        updateTimer?.invalidate()
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: Constants.popoverWidth, height: Constants.popoverHeight)
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: CombinedPopoverView(appState: appState, statusBarController: self)
        )
    }

    private func setupStatusItem() {
        statusItem.button?.action = #selector(togglePopover(_:))
        statusItem.button?.target = self
        Task { @MainActor [weak self] in
            self?.updateStatusItemTitle()
        }
    }

    private func startUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(
            timeInterval: 1.0, // Update every second for time display
            target: self,
            selector: #selector(updateStatusItemTitle),
            userInfo: nil,
            repeats: true
        )
    }

    @MainActor
    @objc private func updateStatusItemTitle() {
        guard let currentCity = appState.currentDisplayCity else {
            statusItem.button?.title = Constants.defaultMenuBarTitle
            return
        }

        var titleComponents: [String] = []

        // Add weather info for current city
        if let weather = appState.getWeather(for: currentCity) {
            let weatherEmoji = WeatherService.shared.getWeatherEmoji(forCondition: weather.weatherDesc)
            let tempString = String(format: "%.1f°C", weather.temperature)
            titleComponents.append("\(weatherEmoji) \(tempString)")
        }

        // Add time info
        let timeString = appState.getTimeString(for: currentCity, useSliderTime: false, shortFormat: true)
        titleComponents.append("\(currentCity.emoji) \(currentCity.code) \(timeString)")

        statusItem.button?.title = titleComponents.joined(separator: " | ")
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            hidePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }

    private func showPopover(sender: AnyObject?) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }

    func hidePopover(sender: AnyObject?) {
        popover.performClose(sender)
    }

    func openSettingsWindow() {
        // If settings window is already open, just bring it to front
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Close existing window if open
        settingsWindow?.close()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Constants.settingsWindowWidth, height: Constants.settingsWindowHeight),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.minSize = NSSize(width: Constants.settingsWindowWidth, height: Constants.settingsWindowHeight)

        let citySelectionView = CitySelectionView(onClose: { [weak self] in
            DispatchQueue.main.async {
                self?.settingsWindow = nil
                self?.settingsWindowDelegate = nil
                window.orderOut(nil)
            }
        }).environmentObject(appState)

        window.contentViewController = NSHostingController(rootView: citySelectionView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }
}
