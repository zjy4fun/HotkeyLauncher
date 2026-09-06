import AppKit

@main
struct HotkeyLauncherMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        // Apply early so launch never briefly registers as a foreground Dock app.
        application.setActivationPolicy(.accessory)
        let appDelegate = AppDelegate()
        application.delegate = appDelegate
        application.run()
    }
}
