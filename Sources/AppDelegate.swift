import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    lazy var statusBarController = CombinedStatusBarController()

    func applicationDidFinishLaunching(_: Notification) {
        // Hide from dock
        NSApp.setActivationPolicy(.accessory)

        // Setup status bar
        statusBarController.setup()
    }

    func applicationWillTerminate(_: Notification) {
        statusBarController.cleanup()
    }
}
