import AppKit
import Foundation

@MainActor
final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    weak var statusBarController: CombinedStatusBarController?

    init(statusBarController: CombinedStatusBarController? = nil) {
        self.statusBarController = statusBarController
        super.init()
    }

    func windowShouldClose(_: NSWindow) -> Bool {
        true
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        // Release on the next runloop so the window isn't deallocated mid-close;
        // the identity check avoids clobbering a window opened in the meantime.
        DispatchQueue.main.async { [weak self] in
            guard let controller = self?.statusBarController,
                  controller.settingsWindow === closingWindow else { return }
            controller.settingsWindow = nil
            controller.settingsWindowDelegate = nil
        }
    }
}
