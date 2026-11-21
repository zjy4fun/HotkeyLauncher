import AppKit
import Foundation

@MainActor
enum WindowActivator {
    /// Brings the settings/main window forward without switching to `.regular`,
    /// so the app stays out of the Dock and Command+Tab switcher.
    static func activateSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if NSApp.activationPolicy() != .accessory {
                NSApp.setActivationPolicy(.accessory)
            }

            NSApp.activate(ignoringOtherApps: true)

            if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}
