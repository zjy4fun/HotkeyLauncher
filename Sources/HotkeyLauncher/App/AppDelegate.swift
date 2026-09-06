import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ShortcutStore()
    private var window: NSWindow?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep accessory policy so LSUIElement / menu-bar-only behavior is preserved:
        // no Dock icon, no Command+Tab entry. Windows can still be shown while accessory.
        NSApp.setActivationPolicy(.accessory)
        store.start()
        createWindow()
        createStatusItem()

        if !CommandLine.arguments.contains("--background") {
            showWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    @objc private func showWindow() {
        if window == nil {
            createWindow()
        }

        // Never promote to `.regular` when showing UI — accessory apps can own windows.
        if NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func addApplication() {
        showWindow()
        store.addApplicationFromPanel()
    }

    @objc private func openSelected() {
        store.openSelectedShortcut()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func createWindow() {
        guard window == nil else {
            return
        }

        let content = ContentView()
            .environmentObject(store)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Hotkey Launcher"
        window.minSize = NSSize(width: 700, height: 400)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: content)
        window.setFrameAutosaveName("HotkeyLauncherMainWindow")
        window.setFrame(NSRect(x: 0, y: 0, width: 900, height: 560), display: true)
        window.center()
        self.window = window
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Hotkey Launcher")
        item.menu = makeStatusMenu()
        statusItem = item
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(
            withTitle: "Open Hotkey Launcher",
            action: #selector(showWindow),
            keyEquivalent: ""
        ).target = self

        menu.addItem(
            withTitle: "Add Application...",
            action: #selector(addApplication),
            keyEquivalent: ""
        ).target = self

        menu.addItem(.separator())

        menu.addItem(
            withTitle: "Open Selected",
            action: #selector(openSelected),
            keyEquivalent: ""
        ).target = self

        menu.addItem(.separator())

        menu.addItem(
            withTitle: "Quit",
            action: #selector(quit),
            keyEquivalent: ""
        ).target = self

        return menu
    }
}
