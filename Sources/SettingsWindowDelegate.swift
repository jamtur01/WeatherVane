import Foundation
import AppKit

final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    weak var statusBarController: CombinedStatusBarController?

    init(statusBarController: CombinedStatusBarController? = nil) {
        self.statusBarController = statusBarController
        super.init()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }

    func windowWillClose(_ notification: Notification) {
        statusBarController?.settingsWindow = nil
        statusBarController?.settingsWindowDelegate = nil
    }
}