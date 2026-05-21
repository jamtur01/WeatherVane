import SwiftUI
import AppKit

final class CombinedStatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let appState = WeathervaneState()
    private var updateTimer: Timer?
    private var eventMonitor: Any?
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
        popover.contentSize = NSSize(width: Constants.popoverWidth, height: Constants.popoverHeightMin)
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
            withTimeInterval: 1.0, // Update every second for time display
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItemTitle()
            }
        }
    }

    @MainActor
    private func updateStatusItemTitle() {
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
        let timeString = appState.getTimeString(for: currentCity, shortFormat: true)
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
        Task { @MainActor in
            appState.popoverDidOpen()
        }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.hidePopover(sender: nil)
        }
    }

    func hidePopover(sender: AnyObject?) {
        popover.performClose(sender)
        Task { @MainActor in
            appState.popoverDidClose()
        }
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
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

        let delegate = SettingsWindowDelegate(statusBarController: self)
        window.delegate = delegate
        settingsWindowDelegate = delegate

        window.contentViewController = NSHostingController(rootView: citySelectionView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }
}
